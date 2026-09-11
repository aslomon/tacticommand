import XCTest

@testable import CreatorMicroCore

final class ShortcutRecordingTests: XCTestCase {
    func testKeyDownCapturesNormalizedShortcutAndSuppressesEvent() {
        let response = ShortcutRecordingReducer().handle(
            .keyDown(
                key: "D",
                virtualKeyCode: 2,
                modifiers: [.shift, .control, .shift, .function],
                isRepeat: false
            )
        )

        XCTAssertTrue(response.suppressesEvent)
        XCTAssertEqual(
            response.decision,
            .captured(
                KeyShortcut(
                    key: "d",
                    modifiers: [.function, .control, .shift],
                    virtualKeyCode: 2
                )
            )
        )
    }

    func testRecordedPhysicalKeyCodeRoundTripsWithoutBreakingLegacyShortcuts() throws {
        let recorded = KeyShortcut(
            key: "y",
            modifiers: [.function, .control],
            virtualKeyCode: 6
        )

        let encoded = try JSONEncoder().encode(recorded)
        XCTAssertEqual(try JSONDecoder().decode(KeyShortcut.self, from: encoded), recorded)

        let legacyData = Data(#"{"key":"d","modifiers":["control"]}"#.utf8)
        let legacy = try JSONDecoder().decode(KeyShortcut.self, from: legacyData)
        XCTAssertNil(legacy.virtualKeyCode)
        XCTAssertEqual(legacy, KeyShortcut(key: "d", modifiers: [.control]))
    }

    func testEscapeCancelsAndDeleteKeysClearRecording() {
        let reducer = ShortcutRecordingReducer()

        XCTAssertEqual(
            reducer.handle(.keyDown(key: "escape", modifiers: [], isRepeat: false)),
            ShortcutRecordingResponse(decision: .cancelled, suppressesEvent: true)
        )
        for key in ["delete", "forward-delete", "backspace"] {
            XCTAssertEqual(
                reducer.handle(.keyDown(key: key, modifiers: [], isRepeat: false)),
                ShortcutRecordingResponse(decision: .cleared, suppressesEvent: true)
            )
        }
    }

    func testModifierChangesRepeatsAndKeyUpRemainSuppressed() {
        let reducer = ShortcutRecordingReducer()
        let inputs: [ShortcutRecordingInput] = [
            .modifiersChanged,
            .keyUp,
            .keyDown(key: "d", modifiers: [.command], isRepeat: true),
            .keyDown(key: nil, modifiers: [.function], isRepeat: false),
        ]

        for input in inputs {
            XCTAssertEqual(
                reducer.handle(input),
                ShortcutRecordingResponse(decision: .keepRecording, suppressesEvent: true)
            )
        }
    }

    func testFormatterShowsNormalizedCombinationAndMultipleTaps() {
        let formatter = KeyShortcutDisplayFormatter()

        XCTAssertEqual(
            formatter.string(
                for: KeyShortcut(
                    key: "d",
                    modifiers: [.command, .control, .function]
                )
            ),
            "fn + ctrl + cmd + D"
        )
        XCTAssertEqual(
            formatter.string(for: KeyShortcut(key: "fn", pressCount: 2)),
            "fn x2"
        )
        XCTAssertEqual(
            formatter.string(
                for: KeyShortcut(
                    mainKeys: [
                        KeyShortcutKey(key: "j", virtualKeyCode: 38),
                        KeyShortcutKey(key: "k", virtualKeyCode: 40),
                    ],
                    modifiers: [.command]
                )
            ),
            "cmd + J + K"
        )
        XCTAssertEqual(
            formatter.string(
                for: KeyShortcut(
                    mainKeys: [],
                    modifiers: [.control, .shift]
                )
            ),
            "ctrl + shift"
        )
    }

    func testDictationTestGestureDwellsWhileHoldToTalkIsActive() {
        let toggle = DictationBinding(providerID: .rede, behavior: .toggle)
        let hold = DictationBinding(providerID: .rede, behavior: .holdToTalk)
        let planner = DictationTestGesturePlanner()

        XCTAssertEqual(planner.steps(for: toggle), [.send(.pressed)])
        XCTAssertEqual(
            planner.steps(for: hold),
            [
                .send(.pressed),
                .wait(milliseconds: 700),
                .send(.released),
            ]
        )
    }
}
