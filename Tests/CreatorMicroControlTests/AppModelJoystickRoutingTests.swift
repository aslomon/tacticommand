import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelJoystickRoutingTests: XCTestCase {
    func testDesktopDefaultsToArrowKeysAndDoesNotStartPointerMotion() async {
        let fixture = makeFixture()

        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
        XCTAssertFalse(fixture.model.pointerController.isRunning)
    }

    func testChangingFromArrowKeysToPointerReleasesKeyAndStartsPointerMode() async {
        let fixture = makeFixture()
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        fixture.model.setLayerJoystickMode(.pointer)
        await fixture.model.handle(.radial(.init(angle: 0.25, distance: 1)))

        XCTAssertTrue(fixture.events.sent.contains(.init(key: "right", phase: .released)))
        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
        XCTAssertFalse(fixture.model.pointerController.isRunning)

        await fixture.model.handle(.radial(.init(angle: 0.25, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0.25, distance: 1)))

        XCTAssertTrue(fixture.model.pointerController.isRunning)
        fixture.model.stopJoystickInput()
    }

    func testIdleLayerChangeRequiresCenterBeforeArrowModeRearms() async {
        let fixture = makeFixture()

        fixture.model.select(layer: .agents)
        fixture.model.select(layer: .desktop)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        XCTAssertTrue(fixture.events.sent.isEmpty)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))
        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
    }

    func testLayerChangeUsesFreshCenterInsteadOfPreviousLayerDeadZone() async {
        let fixture = makeFixture()
        fixture.model.configuration.setJoystick(
            .init(mode: .arrowKeys, deadZone: 0.9),
            on: .agents
        )
        fixture.model.select(layer: .agents)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0.8)))

        fixture.model.select(layer: .desktop)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0.81)))
        XCTAssertTrue(fixture.events.sent.isEmpty)

        await fixture.model.handle(.radial(.init(angle: 0, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0.81)))
        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
    }

    func testOffModeStopsBothJoystickControllers() async {
        let fixture = makeFixture()
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        fixture.model.setLayerJoystickMode(.off)
        await fixture.model.handle(.radial(.init(angle: 0.25, distance: 1)))

        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
        XCTAssertFalse(fixture.model.pointerController.isRunning)
    }

    func testLayerChangeAndConnectionLossReleaseHeldArrowKey() async {
        let fixture = makeFixture()
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        fixture.model.select(layer: .agents)
        fixture.model.handleJoystickSafety(.init(sequence: 1, state: .disconnected))

        XCTAssertEqual(
            fixture.events.sent.filter { $0 == .init(key: "right", phase: .released) }.count,
            1
        )
    }

    func testAccessibilityLossImmediatelyReleasesAndBlocksArrowInput() async {
        let access = MutableJoystickAccessController(snapshot: .granted)
        let fixture = makeFixture(access: access)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        access.currentSnapshot = .accessibilityDenied
        fixture.model.refreshSystemAccess()
        await fixture.model.handle(.radial(.init(angle: 0.25, distance: 1)))

        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .released))
        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
    }

    func testInputMonitoringLossImmediatelyReleasesArrowInput() async {
        let access = MutableJoystickAccessController(snapshot: .granted)
        let fixture = makeFixture(access: access)
        await fixture.model.handle(.radial(.init(angle: 0.5, distance: 1)))

        access.currentSnapshot = .inputMonitoringDenied
        fixture.model.refreshSystemAccess()
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        XCTAssertEqual(fixture.events.sent.last, .init(key: "left", phase: .released))
        XCTAssertEqual(fixture.events.sent.filter { $0.phase == .pressed }.count, 1)
        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
    }

    func testActionFailureReconcilesRevokedAccessAndReleasesArrowInput() async {
        let access = MutableJoystickAccessController(snapshot: .granted)
        let fixture = makeFixture(access: access)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))
        access.currentSnapshot = .accessibilityDenied

        await fixture.model.execute(
            .init(
                action: .shortOrLongPress(shortPress: .none, longPress: .none),
                phase: .pressed
            )
        )

        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .released))
        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
        XCTAssertEqual(fixture.model.systemAccess, .accessibilityDenied)
    }

    func testPointerFailureRefreshesRevokedAccessAndStopsJoystickInput() async {
        let access = MutableJoystickAccessController(snapshot: .granted)
        let fixture = makeFixture(access: access)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))
        access.currentSnapshot = .accessibilityDenied

        fixture.model.pointerController.onFailure?(.accessibilityPermissionRequired)
        for _ in 0..<20 where fixture.model.systemAccess != .accessibilityDenied {
            await Task.yield()
        }

        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .released))
        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
        XCTAssertEqual(fixture.model.systemAccess, .accessibilityDenied)
    }

    func testTerminationPreparationReleasesBeforeAsyncShutdown() async {
        let fixture = makeFixture()
        await fixture.model.handle(.radial(.init(angle: 0.75, distance: 1)))

        fixture.model.prepareForTermination()
        await fixture.model.handle(.radial(.init(angle: 0.75, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        XCTAssertEqual(fixture.events.sent.last, .init(key: "up", phase: .released))
        XCTAssertEqual(fixture.events.sent.filter { $0.phase == .pressed }.count, 1)
        XCTAssertNil(fixture.model.arrowKeyController.activeKey)
    }

    private func makeFixture(
        access: MutableJoystickAccessController = .init(snapshot: .granted)
    ) -> JoystickModelFixture {
        let events = ModelArrowEvents()
        let arrowController = JoystickArrowKeyController(events: events)
        let model = AppModel(
            configurationStore: temporaryStore(),
            accessController: access,
            initialSystemAccess: access.currentSnapshot,
            arrowKeyController: arrowController
        )
        return JoystickModelFixture(model: model, events: events)
    }

    private func temporaryStore() -> ConfigurationStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return ConfigurationStore(fileURL: url)
    }
}

@MainActor
private struct JoystickModelFixture {
    let model: AppModel
    let events: ModelArrowEvents
}

@MainActor
private final class ModelArrowEvents: JoystickArrowKeyEventSending {
    struct Event: Equatable {
        let key: String
        let phase: ButtonPhase
    }

    private(set) var sent: [Event] = []

    func send(_ shortcut: KeyShortcut, phase: ButtonPhase) -> Result<Void, SystemEventFailure> {
        sent.append(.init(key: shortcut.key, phase: phase))
        return .success(())
    }

    func releaseForCleanup(_ shortcut: KeyShortcut) -> Result<Void, SystemEventFailure> {
        .success(())
    }

    func repeatKey(_ shortcut: KeyShortcut) -> Result<Void, SystemEventFailure> {
        .success(())
    }
}

@MainActor
private final class MutableJoystickAccessController: SystemAccessControlling {
    var currentSnapshot: SystemAccessSnapshot

    init(snapshot: SystemAccessSnapshot) {
        currentSnapshot = snapshot
    }

    func snapshot() -> SystemAccessSnapshot { currentSnapshot }
    func requestAccessibility() -> SystemAccessSnapshot { currentSnapshot }
    func requestInputMonitoring() -> SystemAccessSnapshot { currentSnapshot }
    func openPrivacySettings(_ pane: SystemPrivacyPane) {}
}

extension SystemAccessSnapshot {
    fileprivate static let granted = SystemAccessSnapshot(
        accessibility: .granted,
        inputMonitoring: .granted
    )

    fileprivate static let accessibilityDenied = SystemAccessSnapshot(
        accessibility: .denied,
        inputMonitoring: .granted
    )

    fileprivate static let inputMonitoringDenied = SystemAccessSnapshot(
        accessibility: .granted,
        inputMonitoring: .denied
    )
}
