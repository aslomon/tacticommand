import CoreGraphics
import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class MacVirtualKeyMapTests: XCTestCase {
    func testArrowKeyNamesResolveToNativeMacVirtualKeyCodes() {
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "left"), 123)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "right"), 124)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "down"), 125)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "up"), 126)
    }

    func testRecorderAndSynthesizerShareCanonicalPhysicalKeyNames() {
        XCTAssertEqual(MacVirtualKeyMap.keyName(for: 2), "d")
        XCTAssertEqual(MacVirtualKeyMap.keyName(for: 36), "return")
        XCTAssertEqual(MacVirtualKeyMap.keyName(for: 51), "delete")
        XCTAssertEqual(MacVirtualKeyMap.keyName(for: 53), "escape")
        XCTAssertEqual(MacVirtualKeyMap.keyName(for: 117), "forward-delete")
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "d"), 2)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "enter"), 36)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "delete"), 51)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: "backspace"), 51)
    }

    func testRecorderUsesActiveLayoutLabelForPrintablePhysicalKeys() {
        XCTAssertEqual(
            MacVirtualKeyMap.keyName(for: 6, layoutText: "Y"),
            "y"
        )
        XCTAssertEqual(
            MacVirtualKeyMap.keyName(for: 16, layoutText: "Z"),
            "z"
        )
        XCTAssertEqual(
            MacVirtualKeyMap.keyName(for: 36, layoutText: "\r"),
            "return"
        )
        XCTAssertEqual(
            MacVirtualKeyMap.keyName(for: 65, layoutText: ","),
            ","
        )
    }

    func testRecordedPhysicalKeyCodeWinsOverLegacyNameLookup() {
        let recorded = KeyShortcut(key: "y", virtualKeyCode: 6)
        let legacy = KeyShortcut(key: "y")

        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: recorded), 6)
        XCTAssertEqual(MacVirtualKeyMap.keyCode(for: legacy), 16)
    }

    func testManualSingleCharacterLookupUsesCurrentLayout() {
        let germanLabels: [CGKeyCode: String] = [
            6: "y",
            16: "z",
            43: ",",
            44: "-",
            65: ",",
        ]
        let resolver: (CGKeyCode) -> String? = { germanLabels[$0] }

        XCTAssertEqual(
            MacVirtualKeyMap.keyCode(
                forCurrentLayoutKeyName: "y",
                layoutName: resolver
            ),
            6
        )
        XCTAssertEqual(
            MacVirtualKeyMap.keyCode(
                forCurrentLayoutKeyName: "z",
                layoutName: resolver
            ),
            16
        )
        XCTAssertEqual(
            MacVirtualKeyMap.keyCode(
                forCurrentLayoutKeyName: "keypad-decimal",
                layoutName: resolver
            ),
            65
        )
    }

    func testModifierMapperIncludesFunctionAndIgnoresUnrelatedFlags() {
        let flags: CGEventFlags = [
            .maskSecondaryFn,
            .maskControl,
            .maskShift,
            .maskAlphaShift,
        ]

        XCTAssertEqual(
            MacVirtualKeyMap.modifiers(from: flags),
            [.function, .control, .shift]
        )
    }

    func testFunctionKeyReleaseDropsItsFlagButFnChordKeepsModifierFlag() {
        let standaloneFunction = KeyShortcut(key: "fn", virtualKeyCode: 63)
        XCTAssertTrue(
            MacVirtualKeyMap.flags(for: standaloneFunction, phase: .pressed)
                .contains(.maskSecondaryFn)
        )
        XCTAssertFalse(
            MacVirtualKeyMap.flags(for: standaloneFunction, phase: .released)
                .contains(.maskSecondaryFn)
        )

        let functionChord = KeyShortcut(
            key: "f6",
            modifiers: [.function],
            virtualKeyCode: 97
        )
        XCTAssertTrue(
            MacVirtualKeyMap.flags(for: functionChord, phase: .pressed)
                .contains(.maskSecondaryFn)
        )
        XCTAssertTrue(
            MacVirtualKeyMap.flags(for: functionChord, phase: .released)
                .contains(.maskSecondaryFn)
        )
    }

    func testRecorderLifecycleWaitsForCapturedKeyRelease() throws {
        var lifecycle = MacShortcutRecorderLifecycle()

        lifecycle.start()
        XCTAssertTrue(lifecycle.isActive)
        XCTAssertTrue(lifecycle.acceptsShortcut)

        _ = try XCTUnwrap(lifecycle.awaitKeyUp(2))
        XCTAssertTrue(lifecycle.isActive)
        XCTAssertFalse(lifecycle.acceptsShortcut)
        XCTAssertFalse(lifecycle.consumeKeyUp(3))
        XCTAssertTrue(lifecycle.consumeKeyUp(2))
        XCTAssertFalse(lifecycle.isActive)
    }

    func testRecorderLifecycleStopClearsPendingCapture() {
        var lifecycle = MacShortcutRecorderLifecycle()

        lifecycle.start()
        _ = lifecycle.awaitKeyUp(2)
        lifecycle.stop()
        lifecycle.start()

        XCTAssertTrue(lifecycle.acceptsShortcut)
        XCTAssertFalse(lifecycle.consumeKeyUp(2))
    }

    func testRecorderLifecycleTimeoutIsBoundedAndCannotStopNewCapture() throws {
        var lifecycle = MacShortcutRecorderLifecycle()

        lifecycle.start()
        let staleToken = try XCTUnwrap(lifecycle.awaitKeyUp(2))
        lifecycle.stop()
        lifecycle.start()
        let activeToken = try XCTUnwrap(lifecycle.awaitKeyUp(3))

        XCTAssertEqual(
            MacShortcutRecorderLifecycle.fallbackDelay,
            .milliseconds(750)
        )
        XCTAssertFalse(lifecycle.consumeTimeout(staleToken))
        XCTAssertTrue(lifecycle.isActive)
        XCTAssertTrue(lifecycle.consumeTimeout(activeToken))
        XCTAssertFalse(lifecycle.isActive)
    }
}
