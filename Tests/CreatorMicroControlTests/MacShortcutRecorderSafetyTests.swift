import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

@MainActor
final class MacShortcutRecorderSafetyTests: XCTestCase {
    func testRecorderCanDeinitializeWithoutStartingAnEventTap() {
        weak var recorder: MacShortcutRecorder?
        autoreleasepool {
            let instance = MacShortcutRecorder()
            recorder = instance
        }

        XCTAssertNil(recorder)
    }

    func testCommandQPassesThroughAndCancelsRecording() {
        XCTAssertEqual(
            MacShortcutRecorderSafetyPolicy.response(
                key: "q",
                modifiers: [.command]
            ),
            .cancelAndPassThrough
        )
    }

    func testForceQuitShortcutPassesThroughAndCancelsRecording() {
        XCTAssertEqual(
            MacShortcutRecorderSafetyPolicy.response(
                key: "escape",
                modifiers: [.option, .command]
            ),
            .cancelAndPassThrough
        )
    }

    func testOrdinaryShortcutRemainsRecordable() {
        XCTAssertEqual(
            MacShortcutRecorderSafetyPolicy.response(
                key: "d",
                modifiers: [.control, .shift]
            ),
            .record
        )
    }
}
