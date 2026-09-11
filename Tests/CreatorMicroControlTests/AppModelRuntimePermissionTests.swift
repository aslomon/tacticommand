import AppKit
import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelRuntimePermissionTests: XCTestCase {
    func testApplicationActivationRefreshesGrantedAccessAndStartsRuntimeOnce() async throws {
        let deniedAccess = SystemAccessSnapshot(
            accessibility: .granted,
            inputMonitoring: .denied
        )
        let grantedAccess = SystemAccessSnapshot(
            accessibility: .granted,
            inputMonitoring: .granted
        )
        let accessController = MutableSystemAccessController(snapshot: deniedAccess)
        let connector = CountingUnavailableConnector()
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .milliseconds(5)
        )
        let model = AppModel(
            configurationStore: temporaryStore(),
            coordinator: coordinator,
            accessController: accessController,
            initialSystemAccess: deniedAccess
        )
        model.hasStarted = true
        model.isReady = true
        accessController.currentSnapshot = grantedAccess
        let delegate = CreatorMicroApplicationDelegate()
        delegate.model = model

        delegate.applicationDidBecomeActive(Notification(name: NSApplication.didBecomeActiveNotification))
        model.refreshSystemAccess()
        try await connector.waitForConnectionAttempt()
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(model.systemAccess, grantedAccess)
        XCTAssertNotNil(model.runtimeTask)
        let attempts = await connector.connectionAttempts()
        XCTAssertEqual(attempts, 1)
        await model.shutdown()
    }

    func testMissingInputMonitoringBlocksConnectorAndReportsPermission() async throws {
        let connector = CountingUnavailableConnector()
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .milliseconds(5),
            statusTimeout: .milliseconds(5)
        )
        let model = AppModel(
            configurationStore: temporaryStore(),
            coordinator: coordinator,
            initialSystemAccess: SystemAccessSnapshot(
                accessibility: .granted,
                inputMonitoring: .denied
            )
        )

        model.startRuntime()
        try await Task.sleep(for: .milliseconds(30))
        let attempts = await connector.connectionAttempts()

        XCTAssertNil(model.runtimeTask)
        XCTAssertEqual(attempts, 0)
        XCTAssertEqual(
            model.connectionState,
            .unavailable(reason: "Input Monitoring permission is required")
        )
    }

    func testGrantedInputMonitoringStartsConnectorNormally() async throws {
        let connector = CountingUnavailableConnector()
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .milliseconds(5)
        )
        let model = AppModel(
            configurationStore: temporaryStore(),
            coordinator: coordinator,
            initialSystemAccess: SystemAccessSnapshot(
                accessibility: .granted,
                inputMonitoring: .granted
            )
        )

        model.startRuntime()
        try await connector.waitForConnectionAttempt()
        let attempts = await connector.connectionAttempts()

        XCTAssertNotNil(model.runtimeTask)
        XCTAssertEqual(attempts, 1)
        await model.shutdown()
    }

    func testShutdownCancelsAndAwaitsAutomationServerStartup() async throws {
        let model = AppModel(configurationStore: temporaryStore())
        let startupProbe = ControlledAutomationStartupProbe()
        let completionProbe = ShutdownCompletionProbe()
        model.automationServerStartTask = Task {
            await startupProbe.run()
        }
        try await startupProbe.waitUntilStarted()

        let shutdownTask = Task {
            await model.shutdown()
            await completionProbe.finish()
        }
        try await startupProbe.waitUntilCancelled()

        let finishedBeforeRelease = await completionProbe.isFinished
        XCTAssertFalse(finishedBeforeRelease)
        await startupProbe.release()
        await shutdownTask.value

        let snapshot = await startupProbe.snapshot
        XCTAssertEqual(snapshot, StartupProbeSnapshot(cancelled: true, finished: true))
        XCTAssertNil(model.automationServerStartTask)
    }

    func testShutdownCancelsAndAwaitsOwnedReconnectTask() async throws {
        let model = AppModel(configurationStore: temporaryStore())
        let reconnectProbe = ControlledAutomationStartupProbe()
        let completionProbe = ShutdownCompletionProbe()
        model.reconnectTask = Task {
            await reconnectProbe.run()
        }
        try await reconnectProbe.waitUntilStarted()

        let shutdownTask = Task {
            await model.shutdown()
            await completionProbe.finish()
        }
        try await reconnectProbe.waitUntilCancelled()

        let finishedBeforeRelease = await completionProbe.isFinished
        XCTAssertFalse(finishedBeforeRelease)
        await reconnectProbe.release()
        await shutdownTask.value

        let snapshot = await reconnectProbe.snapshot
        XCTAssertEqual(snapshot, StartupProbeSnapshot(cancelled: true, finished: true))
        XCTAssertNil(model.reconnectTask)
    }

    private func temporaryStore() -> ConfigurationStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return ConfigurationStore(fileURL: url)
    }
}

@MainActor
private final class MutableSystemAccessController: SystemAccessControlling {
    var currentSnapshot: SystemAccessSnapshot

    init(snapshot: SystemAccessSnapshot) {
        currentSnapshot = snapshot
    }

    func snapshot() -> SystemAccessSnapshot {
        currentSnapshot
    }

    func requestAccessibility() -> SystemAccessSnapshot {
        currentSnapshot
    }

    func requestInputMonitoring() -> SystemAccessSnapshot {
        currentSnapshot
    }

    func openPrivacySettings(_ pane: SystemPrivacyPane) {}
}

private actor ControlledAutomationStartupProbe {
    private var started = false
    private var cancelled = false
    private var finished = false
    private var continuation: CheckedContinuation<Void, Never>?

    var snapshot: StartupProbeSnapshot {
        StartupProbeSnapshot(cancelled: cancelled, finished: finished)
    }

    func run() async {
        started = true
        do {
            try await Task.sleep(for: .seconds(30))
        } catch {
            cancelled = true
        }
        await withCheckedContinuation { continuation = $0 }
        finished = true
    }

    func waitUntilStarted() async throws {
        for _ in 0..<100 {
            if started { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw RuntimePermissionTestFailure.timeout
    }

    func waitUntilCancelled() async throws {
        for _ in 0..<100 {
            if cancelled { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw RuntimePermissionTestFailure.timeout
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private actor ShutdownCompletionProbe {
    private(set) var isFinished = false

    func finish() {
        isFinished = true
    }
}

private struct StartupProbeSnapshot: Equatable {
    let cancelled: Bool
    let finished: Bool
}

private actor CountingUnavailableConnector: MicroTransportConnector {
    private var attempts = 0

    func connect() async throws -> any MicroTransport {
        attempts += 1
        throw MicroConnectionError.deviceNotFound
    }

    func connectionAttempts() -> Int {
        attempts
    }

    func waitForConnectionAttempt() async throws {
        for _ in 0..<100 {
            if attempts > 0 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw RuntimePermissionTestFailure.timeout
    }
}

private enum RuntimePermissionTestFailure: Error {
    case timeout
}
