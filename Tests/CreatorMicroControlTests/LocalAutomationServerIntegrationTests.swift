import CreatorMicroCore
import Darwin
import Foundation
import XCTest

@testable import CreatorMicroControl

final class LocalAutomationServerIntegrationTests: XCTestCase {
    func testStopClosesConnectedClientAndWaitsForSession() async throws {
        let fixture = SocketFixture()
        let counter = HandlerInvocationCounter()
        let server = LocalAutomationServer(
            socketURL: fixture.socketURL,
            handlers: makeHandlers(counter: counter)
        )
        _ = try await server.start().get()
        let client = try LocalAutomationSocket.connect(to: fixture.socketURL)
        defer { LocalAutomationSocket.close(client) }
        try await waitForClient(on: server)
        XCTAssertTrue(LocalAutomationSocket.write(Data("{".utf8), to: client))

        await server.stop()

        let activeClientCount = await server.activeClientCount
        let invocationCount = await counter.count
        XCTAssertEqual(activeClientCount, 0)
        XCTAssertNil(LocalAutomationSocket.read(client))
        XCTAssertEqual(invocationCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.socketURL.path))
        fixture.remove()
    }

    func testSocketDirectoryAndEndpointUseOwnerOnlyPermissions() async throws {
        let fixture = SocketFixture()
        let server = LocalAutomationServer(
            socketURL: fixture.socketURL,
            handlers: makeHandlers(counter: HandlerInvocationCounter())
        )
        _ = try await server.start().get()

        XCTAssertEqual(posixMode(at: fixture.directoryURL), 0o700)
        XCTAssertEqual(posixMode(at: fixture.socketURL), 0o600)
        let client = try LocalAutomationSocket.connect(to: fixture.socketURL)
        XCTAssertTrue(LocalAutomationSocket.isCurrentUserPeer(client))
        LocalAutomationSocket.close(client)

        await server.stop()
        fixture.remove()
    }

    func testStopCancelsAndAwaitsActiveHandler() async throws {
        let fixture = SocketFixture()
        let probe = CancellableStatusProbe()
        let server = LocalAutomationServer(
            socketURL: fixture.socketURL,
            handlers: makeHandlers(probe: probe)
        )
        _ = try await server.start().get()
        let client = try LocalAutomationSocket.connect(to: fixture.socketURL)
        defer { LocalAutomationSocket.close(client) }
        let request = LocalAutomationRequest(id: "stop-test", command: .status)
        let data = try LocalAutomationCodec().encode(request) + Data([0x0A])
        XCTAssertTrue(LocalAutomationSocket.write(data, to: client))
        try await probe.waitUntilStarted()

        await server.stop()

        let snapshot = await probe.snapshot
        XCTAssertEqual(snapshot, ProbeSnapshot(invocations: 1, cancelled: true, finished: true))
        XCTAssertNil(LocalAutomationSocket.read(client))
        fixture.remove()
    }

    func testStopInvalidatesStartSuspendedBeforeListenerCreation() async throws {
        let fixture = SocketFixture()
        let checkpoint = ServerStartupCheckpoint()
        let server = LocalAutomationServer(
            socketURL: fixture.socketURL,
            handlers: makeHandlers(counter: HandlerInvocationCounter()),
            startupCheckpoint: { await checkpoint.suspend() }
        )
        let starting = Task { await server.start() }
        try await checkpoint.waitUntilEntered()

        await server.stop()
        await checkpoint.release()

        let startResult = await starting.value
        XCTAssertEqual(startResult, .failure(.startupCancelled))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.socketURL.path))
        fixture.remove()
    }

    private func waitForClient(on server: LocalAutomationServer) async throws {
        for _ in 0..<200 {
            if await server.activeClientCount == 1 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw SocketIntegrationFailure.timeout
    }
}

private actor HandlerInvocationCounter {
    private(set) var count = 0

    func recordStatus() -> LocalAutomationStatus {
        count += 1
        return LocalAutomationStatus(
            activeLayer: .desktop,
            isReady: true,
            connection: .disconnected
        )
    }
}

private actor CancellableStatusProbe {
    private var invocations = 0
    private var cancelled = false
    private var finished = false

    var snapshot: ProbeSnapshot {
        ProbeSnapshot(
            invocations: invocations,
            cancelled: cancelled,
            finished: finished
        )
    }

    func status() async -> LocalAutomationStatus {
        invocations += 1
        do {
            try await Task.sleep(for: .seconds(30))
        } catch is CancellationError {
            cancelled = true
        } catch {}
        finished = true
        return testStatus()
    }

    func waitUntilStarted() async throws {
        for _ in 0..<200 {
            if invocations == 1 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw SocketIntegrationFailure.timeout
    }
}

private actor ServerStartupCheckpoint {
    private var entered = false
    private var continuation: CheckedContinuation<Void, Never>?

    func suspend() async {
        entered = true
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilEntered() async throws {
        for _ in 0..<200 {
            if entered { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw SocketIntegrationFailure.timeout
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private struct ProbeSnapshot: Equatable {
    let invocations: Int
    let cancelled: Bool
    let finished: Bool
}

private struct SocketFixture: Sendable {
    let directoryURL: URL
    let socketURL: URL

    init() {
        let identifier = UUID().uuidString.prefix(8)
        directoryURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
            .appendingPathComponent("cmc-\(identifier)", isDirectory: true)
            .appendingPathComponent("Automation", isDirectory: true)
        socketURL = directoryURL.appendingPathComponent("control-v1.sock")
    }

    func remove() {
        try? FileManager.default.removeItem(
            at: directoryURL.deletingLastPathComponent()
        )
    }
}

private enum SocketIntegrationFailure: Error {
    case timeout
}

private func makeHandlers(
    counter: HandlerInvocationCounter
) -> LocalAutomationHandlers {
    makeHandlers(status: { await counter.recordStatus() })
}

private func makeHandlers(
    probe: CancellableStatusProbe
) -> LocalAutomationHandlers {
    makeHandlers(status: { await probe.status() })
}

private func makeHandlers(
    status: @escaping LocalAutomationHandlers.StatusHandler
) -> LocalAutomationHandlers {
    LocalAutomationHandlers(
        status: status,
        listLayers: { [] },
        setLayer: { _ in .success(()) },
        resolveBinding: { _, _ in .none },
        perform: { _ in .success(()) }
    )
}

private func testStatus() -> LocalAutomationStatus {
    LocalAutomationStatus(
        activeLayer: .desktop,
        isReady: true,
        connection: .disconnected
    )
}

private func posixMode(at url: URL) -> mode_t? {
    var metadata = stat()
    guard url.path.withCString({ lstat($0, &metadata) }) == 0 else {
        return nil
    }
    return metadata.st_mode & 0o777
}
