import AppKit
import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class WorkspacePermissionRefreshTests: XCTestCase {
    func testWorkspaceActivationRefreshesAccessAndStartsRuntimeOnce() async throws {
        let fixture = makeFixture()
        let delegate = CreatorMicroApplicationDelegate()
        delegate.model = fixture.model
        fixture.model.hasStarted = true
        fixture.model.isReady = true
        fixture.accessController.currentSnapshot = fixture.grantedAccess

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        let center = NSWorkspace.shared.notificationCenter
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared)
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared)
        try await fixture.connector.waitForConnectionAttempt()

        let attempts = await fixture.connector.connectionAttempts()
        XCTAssertEqual(fixture.model.systemAccess, fixture.grantedAccess)
        XCTAssertNotNil(fixture.model.runtimeTask)
        XCTAssertEqual(attempts, 1)

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        fixture.accessController.currentSnapshot = fixture.deniedAccess
        center.post(name: NSWorkspace.didActivateApplicationNotification, object: NSWorkspace.shared)
        XCTAssertEqual(fixture.model.systemAccess, fixture.grantedAccess)
        await fixture.model.shutdown()
    }

    private func makeFixture() -> WorkspacePermissionFixture {
        let deniedAccess = SystemAccessSnapshot(accessibility: .granted, inputMonitoring: .denied)
        let accessController = WorkspaceTestSystemAccessController(snapshot: deniedAccess)
        let connector = WorkspaceActivationCountingConnector()
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
        return WorkspacePermissionFixture(
            model: model,
            accessController: accessController,
            connector: connector,
            deniedAccess: deniedAccess,
            grantedAccess: SystemAccessSnapshot(accessibility: .granted, inputMonitoring: .granted)
        )
    }

    private func temporaryStore() -> ConfigurationStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return ConfigurationStore(fileURL: url)
    }
}

private struct WorkspacePermissionFixture {
    let model: AppModel
    let accessController: WorkspaceTestSystemAccessController
    let connector: WorkspaceActivationCountingConnector
    let deniedAccess: SystemAccessSnapshot
    let grantedAccess: SystemAccessSnapshot
}

@MainActor
private final class WorkspaceTestSystemAccessController: SystemAccessControlling {
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

private actor WorkspaceActivationCountingConnector: MicroTransportConnector {
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
        throw WorkspacePermissionTestFailure.timeout
    }
}

private enum WorkspacePermissionTestFailure: Error {
    case timeout
}
