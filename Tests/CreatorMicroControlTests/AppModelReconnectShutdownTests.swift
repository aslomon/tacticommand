import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelReconnectShutdownTests: XCTestCase {
    func testShutdownPreventsPendingReconnectFromRestartingCoordinator() async throws {
        let transport = ReconnectBlockingTransport()
        let connector = CountingSingleTransportConnector(transport)
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let model = AppModel(
            configurationStore: temporaryStore(),
            coordinator: coordinator,
            initialSystemAccess: SystemAccessSnapshot(
                accessibility: .granted,
                inputMonitoring: .granted
            )
        )
        model.isReady = true
        model.startRuntime()
        try await transport.waitForWrite()
        await transport.injectStatus()
        try await waitUntilConnected(model)

        model.beginReconnect()
        try await transport.waitUntilCloseStarted()
        let shutdownTask = Task { await model.shutdown() }
        try await waitUntilReconnectCancelled(model)
        await transport.releaseClose()
        await shutdownTask.value

        let attempts = await connector.connectionAttempts
        let coordinatorState = await coordinator.connectionState
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(coordinatorState, .disconnected)
        XCTAssertNil(model.reconnectTask)
    }

    private func temporaryStore() -> ConfigurationStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return ConfigurationStore(fileURL: url)
    }
}

private actor CountingSingleTransportConnector: MicroTransportConnector {
    private var transport: (any MicroTransport)?
    private(set) var connectionAttempts = 0

    init(_ transport: any MicroTransport) {
        self.transport = transport
    }

    func connect() async throws -> any MicroTransport {
        connectionAttempts += 1
        guard let transport else { throw MicroConnectionError.deviceNotFound }
        self.transport = nil
        return transport
    }
}

private actor ReconnectBlockingTransport: MicroTransport {
    nonisolated let kind = MicroTransportKind.usb
    nonisolated let incomingReports: AsyncStream<Data>

    private let continuation: AsyncStream<Data>.Continuation
    private var writes: [Data] = []
    private var closeStarted = false
    private var closeReleased = false
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []

    init() {
        let stream = AsyncStream<Data>.makeStream()
        incomingReports = stream.stream
        continuation = stream.continuation
    }

    func write(_ report: Data) async throws {
        writes.append(report)
    }

    func injectStatus() {
        let payload = Data(
            #"{"result":{"version":"test","layer_index":1},"id":1}"#.utf8
        )
        for report in MicroReportFramer.frames(for: payload, transport: kind) {
            continuation.yield(report)
        }
    }

    func close() async {
        closeStarted = true
        if !closeReleased {
            await withCheckedContinuation { closeWaiters.append($0) }
        }
        continuation.finish()
    }

    func releaseClose() {
        closeReleased = true
        let waiters = closeWaiters
        closeWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    func waitForWrite() async throws {
        try await waitUntil { !writes.isEmpty }
    }

    func waitUntilCloseStarted() async throws {
        try await waitUntil { closeStarted }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ReconnectShutdownTestFailure.timeout
    }
}

@MainActor
private func waitUntilConnected(_ model: AppModel) async throws {
    for _ in 0..<200 {
        if case .connected = model.connectionState { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw ReconnectShutdownTestFailure.timeout
}

@MainActor
private func waitUntilReconnectCancelled(_ model: AppModel) async throws {
    for _ in 0..<200 {
        if model.reconnectTask?.isCancelled == true { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw ReconnectShutdownTestFailure.timeout
}

private enum ReconnectShutdownTestFailure: Error {
    case timeout
}
