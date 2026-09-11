import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class ShortcutRecordingPresentationStateTests: XCTestCase {
    func testDisappearingWhileRecordingReturnsPresentationToIdle() {
        var state = ShortcutRecordingPresentationState()

        state.recordingStarted()
        state.viewDidDisappear()

        XCTAssertFalse(state.isRecording)
    }

    func testRecordingDecisionsPreserveExistingPresentationBehavior() {
        var state = ShortcutRecordingPresentationState()

        state.recordingStarted()
        state.handle(.keepRecording)
        XCTAssertTrue(state.isRecording)

        state.handle(.captured(KeyShortcut(key: "d", modifiers: [.command])))
        XCTAssertFalse(state.isRecording)
    }
}
