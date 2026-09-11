import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

@MainActor
final class JoystickArrowKeyControllerTests: XCTestCase {
    func testDirectionChangeReleasesOldKeyBeforePressingNewKey() {
        let events = RecordingArrowKeyEvents()
        let controller = JoystickArrowKeyController(events: events)

        controller.update(.init(angle: 0, distance: 1), deadZone: 0.1, at: 1)
        controller.update(.init(angle: 0.25, distance: 1), deadZone: 0.1, at: 2)

        XCTAssertEqual(
            events.sent,
            [
                .init(key: "right", phase: .pressed),
                .init(key: "right", phase: .released),
                .init(key: "down", phase: .pressed),
            ]
        )
    }

    func testStopReleasesHeldKeyExactlyOnce() {
        let events = RecordingArrowKeyEvents()
        let controller = JoystickArrowKeyController(events: events)
        controller.update(.init(angle: 0.75, distance: 1), deadZone: 0.1, at: 1)

        controller.stop()
        controller.stop()

        XCTAssertEqual(
            events.sent,
            [
                .init(key: "up", phase: .pressed),
                .init(key: "up", phase: .released),
            ]
        )
        XCTAssertNil(controller.activeKey)
    }

    func testStoppingWhileIdleDoesNotDiscardTheFirstRealDeflection() {
        let events = RecordingArrowKeyEvents()
        let controller = JoystickArrowKeyController(events: events)

        controller.stop()
        controller.update(.init(angle: 0, distance: 1), deadZone: 0.1, at: 1)

        XCTAssertEqual(events.sent, [.init(key: "right", phase: .pressed)])
    }

    func testStaleInputReleasesHeldKey() {
        let events = RecordingArrowKeyEvents()
        let controller = JoystickArrowKeyController(events: events)
        controller.update(.init(angle: 0.5, distance: 1), deadZone: 0.1, at: 10)

        controller.releaseIfStale(at: 14.01)

        XCTAssertEqual(events.sent.last, .init(key: "left", phase: .released))
        XCTAssertNil(controller.activeKey)
    }

    func testHeldDirectionCanEmitMarkedKeyRepeatWithoutAnotherHardwareSample() {
        let events = RecordingArrowKeyEvents()
        let controller = JoystickArrowKeyController(events: events)
        controller.update(.init(angle: 0.25, distance: 1), deadZone: 0.1, at: 1)

        controller.repeatActiveKey()

        XCTAssertEqual(events.repeats, ["down"])
    }

    func testFailedTransitionUsesCleanupReleasesAndResetsState() {
        let events = RecordingArrowKeyEvents(failure: .eventCreationFailed)
        let controller = JoystickArrowKeyController(events: events)
        var failures: [SystemEventFailure] = []
        controller.onFailure = { failures.append($0) }

        controller.update(.init(angle: 0, distance: 1), deadZone: 0.1, at: 1)

        XCTAssertEqual(failures, [.eventCreationFailed])
        XCTAssertNil(controller.activeKey)
        XCTAssertEqual(Set(events.cleanupReleases), Set(["left", "right", "up", "down"]))
    }
}

@MainActor
private final class RecordingArrowKeyEvents: JoystickArrowKeyEventSending {
    struct SentEvent: Equatable {
        let key: String
        let phase: ButtonPhase
    }

    private let failure: SystemEventFailure?
    private(set) var sent: [SentEvent] = []
    private(set) var cleanupReleases: [String] = []
    private(set) var repeats: [String] = []

    init(failure: SystemEventFailure? = nil) {
        self.failure = failure
    }

    func send(_ shortcut: KeyShortcut, phase: ButtonPhase) -> Result<Void, SystemEventFailure> {
        sent.append(.init(key: shortcut.key, phase: phase))
        return failure.map(Result.failure) ?? .success(())
    }

    func releaseForCleanup(_ shortcut: KeyShortcut) -> Result<Void, SystemEventFailure> {
        cleanupReleases.append(shortcut.key)
        return .success(())
    }

    func repeatKey(_ shortcut: KeyShortcut) -> Result<Void, SystemEventFailure> {
        repeats.append(shortcut.key)
        return .success(())
    }
}
