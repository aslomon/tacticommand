import XCTest

@testable import CreatorMicroCore

final class LightingFeedbackTrackerTests: XCTestCase {
    private let origin = ContinuousClock().now

    func testPressRampsTheLiftOverTheAttackDuration() {
        var tracker = LightingFeedbackTracker()
        tracker.press(.agent0, at: origin)

        XCTAssertEqual(tracker.feedback(for: .agent0, at: origin).pressLift, 0, accuracy: 0.001)
        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: origin.advanced(by: .milliseconds(45))).pressLift,
            0.5,
            accuracy: 0.02
        )
        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: origin.advanced(by: .milliseconds(90))).pressLift,
            1,
            accuracy: 0.001
        )
    }

    func testHeldPressStaysFullyLifted() {
        var tracker = LightingFeedbackTracker()
        tracker.press(.agent0, at: origin)

        let held = tracker.feedback(for: .agent0, at: origin.advanced(by: .seconds(5)))
        XCTAssertEqual(held.pressLift, 1, accuracy: 0.001)
    }

    func testReleaseDecaysInsteadOfErasingTheLiftInstantly() {
        var tracker = LightingFeedbackTracker()
        tracker.press(.agent0, at: origin)
        let releaseInstant = origin.advanced(by: .milliseconds(90))
        tracker.release(.agent0, at: releaseInstant)

        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: releaseInstant).pressLift,
            1,
            accuracy: 0.001
        )
        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: releaseInstant.advanced(by: .milliseconds(80))).pressLift,
            0.5,
            accuracy: 0.02
        )
        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: releaseInstant.advanced(by: .milliseconds(160))).pressLift,
            0,
            accuracy: 0.001
        )
    }

    func testReleaseBeforeTheAttackCompletesDecaysFromThePartialLift() {
        var tracker = LightingFeedbackTracker()
        tracker.press(.agent0, at: origin)
        let releaseInstant = origin.advanced(by: .milliseconds(45))
        tracker.release(.agent0, at: releaseInstant)

        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: releaseInstant).pressLift,
            0.5,
            accuracy: 0.02
        )
        XCTAssertEqual(
            tracker.feedback(for: .agent0, at: releaseInstant.advanced(by: .milliseconds(160))).pressLift,
            0,
            accuracy: 0.001
        )
    }

    func testFailureStaysVisibleForItsWindowAndIsNotClearedByPressOrRelease() {
        var tracker = LightingFeedbackTracker()
        tracker.failure(.action6, at: origin)
        tracker.press(.action6, at: origin.advanced(by: .milliseconds(10)))
        tracker.release(.action6, at: origin.advanced(by: .milliseconds(20)))

        XCTAssertTrue(tracker.feedback(for: .action6, at: origin.advanced(by: .milliseconds(900))).isFailing)
        XCTAssertFalse(
            tracker.feedback(for: .action6, at: origin.advanced(by: .milliseconds(1_001))).isFailing
        )
    }

    func testFailureIsScopedToItsOwnControl() {
        var tracker = LightingFeedbackTracker()
        tracker.failure(.action6, at: origin)

        XCTAssertTrue(tracker.feedback(for: .action6, at: origin).isFailing)
        XCTAssertFalse(tracker.feedback(for: .action7, at: origin).isFailing)
    }

    func testResetClearsEveryTransientStateAtABoundary() {
        var tracker = LightingFeedbackTracker()
        tracker.press(.agent0, at: origin)
        tracker.failure(.action6, at: origin)

        tracker.reset()

        XCTAssertEqual(tracker.feedback(for: .agent0, at: origin).pressLift, 0, accuracy: 0.001)
        XCTAssertFalse(tracker.feedback(for: .action6, at: origin).isFailing)
        XCTAssertFalse(tracker.hasActiveFeedback(at: origin))
    }

    func testNextDeadlineSchedulesTheRemainingTransitionAndEndsWhenSettled() {
        var tracker = LightingFeedbackTracker()
        tracker.press(.agent0, at: origin)

        XCTAssertEqual(tracker.nextDeadline(at: origin), origin.advanced(by: .milliseconds(90)))

        tracker.release(.agent0, at: origin.advanced(by: .milliseconds(90)))
        XCTAssertEqual(
            tracker.nextDeadline(at: origin.advanced(by: .milliseconds(90))),
            origin.advanced(by: .milliseconds(250))
        )

        tracker.prune(at: origin.advanced(by: .milliseconds(250)))
        XCTAssertNil(tracker.nextDeadline(at: origin.advanced(by: .milliseconds(250))))
        XCTAssertFalse(tracker.hasActiveFeedback(at: origin.advanced(by: .milliseconds(250))))
    }
}
