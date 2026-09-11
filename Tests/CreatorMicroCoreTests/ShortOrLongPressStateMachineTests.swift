import XCTest

@testable import CreatorMicroCore

final class ShortOrLongPressStateMachineTests: XCTestCase {
    func testReleaseBeforeThresholdEmitsOnlyShortAction() throws {
        var state = ShortOrLongPressStateMachine()
        let deadline = try beginPress(using: &state)

        XCTAssertEqual(
            state.release(control: .action6),
            [
                .emit(.init(action: .openFinder, phase: .pressed)),
                .emit(.init(action: .openFinder, phase: .released)),
            ]
        )
        XCTAssertTrue(state.thresholdReached(deadline).isEmpty)
    }

    func testThresholdAndReleaseEmitLongPressPhasesExactlyOnce() throws {
        var state = ShortOrLongPressStateMachine()
        let deadline = try beginPress(using: &state)

        XCTAssertEqual(
            state.thresholdReached(deadline),
            [.emit(.init(action: .openTerminal, phase: .pressed))]
        )
        XCTAssertTrue(state.thresholdReached(deadline).isEmpty)
        XCTAssertEqual(
            state.release(control: .action6),
            [.emit(.init(action: .openTerminal, phase: .released))]
        )
        XCTAssertTrue(state.release(control: .action6).isEmpty)
    }

    func testDuplicatePressDoesNotReplaceOriginalDeadlineOrActions() throws {
        var state = ShortOrLongPressStateMachine()
        let deadline = try beginPress(using: &state)

        XCTAssertTrue(
            state.begin(
                control: .action6,
                shortPress: .escapeKey,
                longPress: .returnKey
            ).isEmpty
        )
        XCTAssertEqual(
            state.thresholdReached(deadline),
            [.emit(.init(action: .openTerminal, phase: .pressed))]
        )
    }

    func testResetDropsPendingShortAndReleasesEveryActiveLongInControlOrder() throws {
        var state = ShortOrLongPressStateMachine()
        let later = try beginPress(control: .action7, using: &state)
        let earlier = try beginPress(control: .action6, using: &state)
        _ = state.thresholdReached(later)
        _ = state.thresholdReached(earlier)

        XCTAssertEqual(
            state.reset(),
            [
                .emit(.init(action: .openTerminal, phase: .released)),
                .emit(.init(action: .openTerminal, phase: .released)),
            ]
        )
        XCTAssertFalse(state.isTracking(.action6))
        XCTAssertFalse(state.isTracking(.action7))
    }

    func testResetOfPendingPressDoesNotFireShortAction() throws {
        var state = ShortOrLongPressStateMachine()
        _ = try beginPress(using: &state)

        XCTAssertTrue(state.reset().isEmpty)
        XCTAssertFalse(state.isTracking(.action6))
    }

    private func beginPress(
        control: ControlID = .action6,
        using state: inout ShortOrLongPressStateMachine
    ) throws -> ShortOrLongPressDeadline {
        let effects = state.begin(
            control: control,
            shortPress: .openFinder,
            longPress: .openTerminal
        )
        guard effects.count == 1,
            case .schedule(let deadline) = effects[0]
        else {
            throw StateMachineTestFailure.missingDeadline
        }
        XCTAssertEqual(deadline.delayMilliseconds, 450)
        return deadline
    }
}

private enum StateMachineTestFailure: Error {
    case missingDeadline
}
