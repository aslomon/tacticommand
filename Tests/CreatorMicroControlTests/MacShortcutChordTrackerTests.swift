import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class MacShortcutChordTrackerTests: XCTestCase {
    func testCommandJKCapturesOnlyAfterEveryKeyAndModifierIsReleased() {
        var tracker = MacShortcutChordTracker()

        XCTAssertEqual(tracker.keyDown(key: "j", keyCode: 38, modifiers: [.command]), .keepRecording)
        XCTAssertEqual(tracker.keyDown(key: "k", keyCode: 40, modifiers: [.command]), .keepRecording)
        XCTAssertEqual(tracker.keyUp(keyCode: 38, modifiers: [.command]), .keepRecording)
        XCTAssertEqual(tracker.keyUp(keyCode: 40, modifiers: [.command]), .keepRecording)
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 55, modifiers: []),
            .captured(
                KeyShortcut(
                    mainKeys: [
                        KeyShortcutKey(key: "j", virtualKeyCode: 38),
                        KeyShortcutKey(key: "k", virtualKeyCode: 40),
                    ],
                    modifiers: [.command]
                )
            )
        )
    }

    func testDuplicateKeyDownIsDeduplicatedAndNewKeysStopAfterReleaseBegins() {
        var tracker = MacShortcutChordTracker()

        _ = tracker.keyDown(key: "j", keyCode: 38, modifiers: [])
        _ = tracker.keyDown(key: "j", keyCode: 38, modifiers: [])
        XCTAssertEqual(
            tracker.keyUp(keyCode: 38, modifiers: []),
            .captured(
                KeyShortcut(
                    mainKeys: [KeyShortcutKey(key: "j", virtualKeyCode: 38)]
                )
            )
        )
    }

    func testFunctionShiftWaitsForBothModifierKeysToBeReleased() {
        var tracker = MacShortcutChordTracker()

        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 63, modifiers: [.function, .shift]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 63, modifiers: [.shift]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 56, modifiers: []),
            .captured(
                KeyShortcut(
                    key: "fn",
                    modifiers: [.shift],
                    virtualKeyCode: 63
                )
            )
        )
    }

    func testFallbackSnapshotNeverCompletesWhileModifierIsPhysicallyHeld() {
        var tracker = MacShortcutChordTracker()

        _ = tracker.keyDown(key: "j", keyCode: 38, modifiers: [.command])
        _ = tracker.keyUp(keyCode: 38, modifiers: [.command])

        for _ in 0..<3 {
            XCTAssertEqual(
                tracker.reconcileCurrentModifiers([.command]),
                .keepRecording
            )
            XCTAssertTrue(tracker.isWaitingForModifierRelease)
        }
        XCTAssertEqual(
            tracker.reconcileCurrentModifiers([]),
            .captured(
                KeyShortcut(
                    key: "j",
                    modifiers: [.command],
                    virtualKeyCode: 38
                )
            )
        )
    }

    func testLateKeyDownBlocksCompletionWithoutJoiningCapturedChord() {
        var tracker = MacShortcutChordTracker()

        _ = tracker.keyDown(key: "j", keyCode: 38, modifiers: [.command])
        _ = tracker.keyUp(keyCode: 38, modifiers: [.command])
        XCTAssertEqual(
            tracker.keyDown(key: "k", keyCode: 40, modifiers: [.command]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 55, modifiers: []),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.keyUp(keyCode: 40, modifiers: []),
            .captured(
                KeyShortcut(
                    key: "j",
                    modifiers: [.command],
                    virtualKeyCode: 38
                )
            )
        )
    }

    func testLateUnmappedKeyDownBlocksCompletionUntilItsKeyUp() {
        var tracker = MacShortcutChordTracker()

        _ = tracker.keyDown(key: "j", keyCode: 38, modifiers: [.command])
        _ = tracker.keyUp(keyCode: 38, modifiers: [.command])
        XCTAssertEqual(
            tracker.keyDown(key: nil, keyCode: 99, modifiers: [.command]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 55, modifiers: []),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.keyUp(keyCode: 99, modifiers: []),
            .captured(
                KeyShortcut(
                    key: "j",
                    modifiers: [.command],
                    virtualKeyCode: 38
                )
            )
        )
    }

    func testControlShiftCapturesAsModifierOnlyChordAfterFullRelease() {
        var tracker = MacShortcutChordTracker()

        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 59, modifiers: [.control]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 56, modifiers: [.control, .shift]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 59, modifiers: [.shift]),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 56, modifiers: []),
            .captured(
                KeyShortcut(
                    mainKeys: [],
                    modifiers: [.control, .shift]
                )
            )
        )
    }

    func testKeyPressedAfterModifierReleaseBlocksWithoutJoiningChord() {
        var tracker = MacShortcutChordTracker()

        _ = tracker.modifiersChanged(keyCode: 59, modifiers: [.control])
        _ = tracker.modifiersChanged(keyCode: 56, modifiers: [.control, .shift])
        _ = tracker.modifiersChanged(keyCode: 56, modifiers: [.control])
        _ = tracker.keyDown(key: "j", keyCode: 38, modifiers: [.control])
        XCTAssertEqual(
            tracker.modifiersChanged(keyCode: 59, modifiers: []),
            .keepRecording
        )
        XCTAssertEqual(
            tracker.keyUp(keyCode: 38, modifiers: []),
            .captured(
                KeyShortcut(
                    mainKeys: [],
                    modifiers: [.control, .shift]
                )
            )
        )
    }
}
