import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDeviceCoordinatorShutdownTests: XCTestCase {
    func testStopRejectsSendBeforeWaitingForTransportClose() async throws {
        let transport = BlockingCloseTransport()
        let coordinator = MicroDeviceCoordinator(
            connector: OneTransportConnector(transport),
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        await coordinator.start()
        try await transport.waitForWriteCount(1)
        await transport.injectStatus()
        try await waitUntilConnected(coordinator)
        await transport.clearWrites()

        let stopTask = Task { await coordinator.stop() }
        try await transport.waitUntilCloseStarted()
        let sendFailure: MicroConnectionError?
        do {
            try await coordinator.send(payload: Data("blocked-during-stop".utf8))
            sendFailure = nil
        } catch let failure as MicroConnectionError {
            sendFailure = failure
        } catch {
            XCTFail("Unexpected send error: \(error)")
            sendFailure = nil
        }

        XCTAssertEqual(sendFailure, .notConnected)
        let writeCount = await transport.writeCount
        XCTAssertEqual(writeCount, 0)
        await transport.releaseClose()
        await stopTask.value
        let state = await coordinator.connectionState
        XCTAssertEqual(state, .disconnected)
    }

    func testCancelledConnectClosesReturnedTransportWithoutWriting() async throws {
        let connector = DeferredTransportConnector()
        let transport = CloseTrackingTransport()
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        await coordinator.start()
        try await connector.waitUntilSuspended()

        let stopTask = Task { await coordinator.stop() }
        try await connector.waitUntilCancelled()
        await connector.resume(with: transport)
        await stopTask.value

        let writeCount = await transport.writeCount
        let closeCount = await transport.closeCount
        let state = await coordinator.connectionState
        XCTAssertEqual(writeCount, 0)
        XCTAssertEqual(closeCount, 1)
        XCTAssertEqual(state, .disconnected)
    }
}

private actor OneTransportConnector: MicroTransportConnector {
    private var transport: (any MicroTransport)?

    init(_ transport: any MicroTransport) {
        self.transport = transport
    }

    func connect() async throws -> any MicroTransport {
        guard let transport else { throw MicroConnectionError.deviceNotFound }
        self.transport = nil
        return transport
    }
}

private actor BlockingCloseTransport: MicroTransport {
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

    var writeCount: Int { writes.count }

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

    func clearWrites() {
        writes.removeAll()
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

    func waitForWriteCount(_ expected: Int) async throws {
        try await waitUntil { writes.count >= expected }
    }

    func waitUntilCloseStarted() async throws {
        try await waitUntil { closeStarted }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CoordinatorShutdownTestFailure.timeout
    }
}

private actor DeferredTransportConnector: MicroTransportConnector {
    private var continuation: CheckedContinuation<any MicroTransport, Never>?
    private var cancellationObserved = false

    func connect() async throws -> any MicroTransport {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation = $0 }
        } onCancel: {
            Task { await self.recordCancellation() }
        }
    }

    func resume(with transport: any MicroTransport) {
        continuation?.resume(returning: transport)
        continuation = nil
    }

    func waitUntilSuspended() async throws {
        try await waitUntil { continuation != nil }
    }

    func waitUntilCancelled() async throws {
        try await waitUntil { cancellationObserved }
    }

    private func recordCancellation() {
        cancellationObserved = true
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CoordinatorShutdownTestFailure.timeout
    }
}

private actor CloseTrackingTransport: MicroTransport {
    nonisolated let kind = MicroTransportKind.usb
    nonisolated let incomingReports: AsyncStream<Data>

    private let continuation: AsyncStream<Data>.Continuation
    private(set) var writeCount = 0
    private(set) var closeCount = 0

    init() {
        let stream = AsyncStream<Data>.makeStream()
        incomingReports = stream.stream
        continuation = stream.continuation
    }

    func write(_ report: Data) async throws {
        writeCount += 1
    }

    func close() async {
        closeCount += 1
        continuation.finish()
    }
}

private func waitUntilConnected(_ coordinator: MicroDeviceCoordinator) async throws {
    for _ in 0..<200 {
        if case .connected = await coordinator.connectionState { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw CoordinatorShutdownTestFailure.timeout
}

private enum CoordinatorShutdownTestFailure: Error {
    case timeout
}
