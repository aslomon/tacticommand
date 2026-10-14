import Foundation

public protocol MicroTransportConnector: Sendable {
    func connect() async throws -> any MicroTransport
}

public enum MicroConnectionError: Error, Equatable, LocalizedError {
    case deviceNotFound
    case notConnected
    case statusRoundTripTimedOut
    case unsupportedStatusMethod
    case transportDisconnected
    case outputReportFailed(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            "Creator Micro 2 was not found."
        case .notConnected:
            "Creator Micro 2 is not connected and verified."
        case .statusRoundTripTimedOut:
            "The device.status round trip timed out."
        case .unsupportedStatusMethod:
            "This firmware does not support device.status. Install the official firmware update for your controller."
        case .transportDisconnected:
            "Creator Micro 2 disconnected."
        case .outputReportFailed(let code):
            "Writing the HID output report failed with IOKit code \(code)."
        }
    }
}

public enum MicroCoordinatorUpdate: Equatable, Sendable {
    case connection(DeviceConnectionState)
    case event(MicroDeviceEvent)
    case diagnostic(String)
}

public actor MicroDeviceCoordinator {
    private static let statusRequestIdentifier = 1

    public private(set) var connectionState: DeviceConnectionState = .disconnected

    private let connector: any MicroTransportConnector
    private let retryDelay: Duration
    private let statusTimeout: Duration
    var updateSubscribers: [UUID: MicroUpdateSubscriber] = [:]
    var radialUpdateContinuations: [UUID: AsyncStream<SequencedRadialUpdate>.Continuation] = [:]
    var connectionUpdateContinuations: [UUID: AsyncStream<SequencedConnectionUpdate>.Continuation] =
        [:]
    var updateSequence: UInt64 = 0
    var connectionStateSequence: UInt64 = 0
    var verifiedConnectionSequence: UInt64?
    public private(set) var identitySnapshot: DeviceIdentitySnapshot?
    var identityUpdateContinuations: [UUID: AsyncStream<DeviceIdentitySnapshot?>.Continuation] = [:]
    private let outboundWriter = MicroOutboundWriter()
    var activeTransport: (any MicroTransport)?
    private var worker: Task<Void, Never>?
    private var stopTask: Task<Void, Never>?
    var isVerified = false
    var pendingRPC: [Int: PendingMicroRPC] = [:]
    var rpcWriteTasks: [Int: Task<Void, Never>] = [:]
    var nextRPCIdentifier = 2

    public init(
        connector: any MicroTransportConnector,
        retryDelay: Duration = .seconds(1),
        statusTimeout: Duration = .seconds(2)
    ) {
        self.connector = connector
        self.retryDelay = retryDelay
        self.statusTimeout = statusTimeout
    }

    public func start() {
        guard worker == nil, stopTask == nil else { return }
        worker = Task { [weak self] in
            await self?.runConnectionLoop()
        }
    }

    public func stop() async {
        if let stopTask {
            await stopTask.value
            return
        }
        let runningWorker = worker
        let transport = activeTransport
        runningWorker?.cancel()
        worker = nil
        activeTransport = nil
        isVerified = false
        cancelRPC()
        setIdentity(nil)
        publish(connection: .disconnected)
        let cleanup = Task {
            await outboundWriter.drain()
            if let transport { await transport.close() }
            await runningWorker?.value
        }
        stopTask = cleanup
        await cleanup.value
        stopTask = nil
        if connectionState != .disconnected {
            publish(connection: .disconnected)
        }
    }

    public func send(payload: Data) async throws {
        guard let activeTransport, isVerified else {
            throw MicroConnectionError.notConnected
        }
        try await write(payload, to: activeTransport)
    }

    private func runConnectionLoop() async {
        while !Task.isCancelled {
            publish(connection: .connecting)
            do {
                let transport = try await connector.connect()
                try await runConnection(transport)
            } catch is CancellationError {
                break
            } catch {
                guard !Task.isCancelled else { break }
                publish(connection: .unavailable(reason: message(for: error)))
                do {
                    try await Task.sleep(for: retryDelay)
                } catch {
                    break
                }
            }
        }
    }

    private func runConnection(_ transport: any MicroTransport) async throws {
        let roundTrip = StatusRoundTrip()
        var reader: Task<Void, Never>?
        var registeredTransport = false
        do {
            try Task.checkCancellation()
            activeTransport = transport
            nextRPCIdentifier = 2
            isVerified = false
            cancelRPC()
            registeredTransport = true
            let reportReader = Task { [weak self] in
                guard let self else { return }
                await self.readReports(from: transport, roundTrip: roundTrip)
            }
            reader = reportReader
            let request = try MicroCommandBuilder.deviceStatusRequest(
                identifier: Self.statusRequestIdentifier
            )
            try await write(request, to: transport)
            let status = try await verifiedStatus(roundTrip)
            try Task.checkCancellation()
            isVerified = true
            setIdentity(
                DeviceIdentitySnapshot(
                    transport: transport.kind,
                    productIdentifier: transport.productIdentifier
                )
            )
            publish(connection: .connected(transport: transport.kind, status: status))
            await reportReader.value
            if Task.isCancelled { throw CancellationError() }
            throw MicroConnectionError.transportDisconnected
        } catch {
            reader?.cancel()
            let shouldClose = !registeredTransport || activeTransport != nil
            activeTransport = nil
            isVerified = false
            cancelRPC()
            setIdentity(nil)
            if shouldClose { await transport.close() }
            await reader?.value
            throw error
        }
    }

    func setIdentity(_ snapshot: DeviceIdentitySnapshot?) {
        identitySnapshot = snapshot
        for continuation in identityUpdateContinuations.values {
            continuation.yield(snapshot)
        }
    }

    private func verifiedStatus(_ roundTrip: StatusRoundTrip) async throws -> DeviceStatus {
        do {
            return try await roundTrip.wait(timeout: statusTimeout)
        } catch MicroMessageParserError.deviceError(let code, _) where code == 404 {
            throw MicroConnectionError.unsupportedStatusMethod
        }
    }

    private func readReports(
        from transport: any MicroTransport,
        roundTrip: StatusRoundTrip
    ) async {
        var decoder = MicroFrameDecoder()
        for await report in transport.incomingReports {
            if Task.isCancelled { break }
            for payload in decoder.feed(report) {
                receive(payload, roundTrip: roundTrip)
            }
        }
        roundTrip.finish()
    }

    private func receive(_ payload: Data, roundTrip: StatusRoundTrip) {
        if isVerified && receiveRPC(payload) { return }
        do {
            let event = try MicroMessageParser.parse(payload)
            guard isVerified else {
                guard case .status(let status) = event,
                    MicroMessageParser.responseIdentifier(payload)
                        == Self.statusRequestIdentifier
                else { return }
                roundTrip.receive(status)
                return
            }
            publish(.event(event))
        } catch {
            if !isVerified,
                MicroMessageParser.responseIdentifier(payload) == Self.statusRequestIdentifier,
                let error = error as? MicroMessageParserError,
                case .deviceError = error
            {
                roundTrip.reject(error)
            }
            publish(.diagnostic(message(for: error)))
        }
    }

    func write(
        _ payload: Data,
        to transport: any MicroTransport
    ) async throws {
        try await outboundWriter.write(payload, to: transport)
    }

    private func publish(connection: DeviceConnectionState) {
        connectionState = connection
        publish(.connection(connection))
    }

    private func message(for error: Error) -> String {
        MicroDiagnosticMessageFormatter.message(for: error)
    }
}

private final class StatusRoundTrip: @unchecked Sendable {
    private let statuses: AsyncStream<Result<DeviceStatus, MicroMessageParserError>>
    private let continuation: AsyncStream<Result<DeviceStatus, MicroMessageParserError>>.Continuation

    init() {
        let stream = AsyncStream<Result<DeviceStatus, MicroMessageParserError>>.makeStream(
            bufferingPolicy: .bufferingOldest(1))
        statuses = stream.stream
        continuation = stream.continuation
    }

    func receive(_ status: DeviceStatus) {
        continuation.yield(.success(status))
        continuation.finish()
    }

    func reject(_ error: MicroMessageParserError) {
        continuation.yield(.failure(error))
        continuation.finish()
    }

    func finish() {
        continuation.finish()
    }

    func wait(timeout: Duration) async throws -> DeviceStatus {
        try await withThrowingTaskGroup(of: DeviceStatus.self) { group in
            group.addTask { [statuses] in
                var iterator = statuses.makeAsyncIterator()
                guard let status = await iterator.next() else {
                    throw MicroConnectionError.transportDisconnected
                }
                return try status.get()
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw MicroConnectionError.statusRoundTripTimedOut
            }
            guard let status = try await group.next() else {
                throw MicroConnectionError.transportDisconnected
            }
            group.cancelAll()
            return status
        }
    }
}
