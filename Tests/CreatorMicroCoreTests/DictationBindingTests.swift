import Foundation
import XCTest

@testable import CreatorMicroCore

final class DictationBindingTests: XCTestCase {
    func testBuiltInDefinitionsExposeExpectedScopeAndDefaults() {
        let rede = BuiltInDictationProvider.rede.definition(availability: .available)
        let chatGPT = BuiltInDictationProvider.chatGPTCodex.definition(availability: .available)
        let apple = BuiltInDictationProvider.appleDictation.definition(availability: .available)

        XCTAssertEqual(rede.displayName, "rede")
        XCTAssertEqual(rede.scope, .systemWide)
        XCTAssertNil(rede.defaultShortcut)
        XCTAssertEqual(rede.defaultBehavior, .toggle)
        XCTAssertEqual(rede.supportedBehaviors, [.holdToTalk, .toggle])

        XCTAssertEqual(chatGPT.displayName, "ChatGPT / Codex")
        XCTAssertEqual(chatGPT.scope, .applicationOnly)
        XCTAssertEqual(
            chatGPT.defaultShortcut,
            KeyShortcut(key: "d", modifiers: [.control, .shift])
        )
        XCTAssertEqual(chatGPT.supportedBehaviors, [.toggle])

        XCTAssertEqual(apple.displayName, "Apple Dictation")
        XCTAssertEqual(apple.scope, .systemWide)
        XCTAssertEqual(
            apple.defaultShortcut,
            KeyShortcut(key: "fn", pressCount: 2)
        )
        XCTAssertEqual(apple.supportedBehaviors, [.toggle])
    }

    func testBindingRetainsProviderBehaviorAndCustomShortcut() {
        let shortcut = KeyShortcut(key: "space", modifiers: [.command, .option])
        let binding = DictationBinding(
            providerID: .rede,
            behavior: .holdToTalk,
            shortcut: shortcut
        )

        XCTAssertEqual(binding.providerID, .rede)
        XCTAssertEqual(binding.behavior, .holdToTalk)
        XCTAssertEqual(binding.shortcut, shortcut)
    }

    func testShortcutNormalizesDuplicateModifiers() {
        let shortcut = KeyShortcut(
            key: "D",
            modifiers: [.shift, .control, .shift, .control]
        )

        XCTAssertEqual(shortcut.key, "d")
        XCTAssertEqual(shortcut.modifiers, [.control, .shift])
    }

    func testShortcutKeepsOrderedDistinctMainKeysAndLegacyAccessors() {
        let shortcut = KeyShortcut(
            mainKeys: [
                KeyShortcutKey(key: "J", virtualKeyCode: 38),
                KeyShortcutKey(key: "K", virtualKeyCode: 40),
                KeyShortcutKey(key: "j", virtualKeyCode: 38),
            ],
            modifiers: [.command]
        )

        XCTAssertEqual(
            shortcut.mainKeys,
            [
                KeyShortcutKey(key: "j", virtualKeyCode: 38),
                KeyShortcutKey(key: "k", virtualKeyCode: 40),
            ]
        )
        XCTAssertEqual(shortcut.key, "j")
        XCTAssertEqual(shortcut.virtualKeyCode, 38)
    }

    func testFunctionMainKeyIsNotDuplicatedAsAModifier() {
        let shortcut = KeyShortcut(
            key: "fn",
            modifiers: [.function, .shift],
            virtualKeyCode: 63
        )

        XCTAssertEqual(shortcut.modifiers, [.shift])
    }

    func testEveryLegacyModifierMainKeyRemovesItsDuplicateModifier() {
        let aliases: [(String, KeyboardModifier)] = [
            ("function", .function),
            ("ctrl", .control),
            ("alt", .option),
            ("shift", .shift),
            ("cmd", .command),
        ]

        for (key, modifier) in aliases {
            let shortcut = KeyShortcut(key: key, modifiers: [modifier])

            XCTAssertTrue(shortcut.modifiers.isEmpty, "Duplicate remained for \(key)")
        }
    }

    func testMultiKeyShortcutRoundTripsAndLegacyJSONMigrates() throws {
        let shortcut = KeyShortcut(
            mainKeys: [
                KeyShortcutKey(key: "j", virtualKeyCode: 38),
                KeyShortcutKey(key: "k", virtualKeyCode: 40),
            ],
            modifiers: [.command],
            displayName: "Open Command Palette"
        )
        let encoded = try JSONEncoder().encode(shortcut)

        XCTAssertEqual(try JSONDecoder().decode(KeyShortcut.self, from: encoded), shortcut)

        let legacy = Data(#"{"key":"d","modifiers":["control"],"virtualKeyCode":2}"#.utf8)
        XCTAssertEqual(
            try JSONDecoder().decode(KeyShortcut.self, from: legacy),
            KeyShortcut(key: "d", modifiers: [.control], virtualKeyCode: 2)
        )
    }

    func testShortcutDisplayNameIsOptionalAndNormalized() {
        XCTAssertEqual(
            KeyShortcut(key: "k", displayName: "  Open Command Palette  ").displayName,
            "Open Command Palette"
        )
        XCTAssertNil(KeyShortcut(key: "k", displayName: "   ").displayName)
        XCTAssertNil(KeyShortcut(key: "k").displayName)
    }

    func testRenamingShortcutPreservesItsRecordedChord() {
        let original = KeyShortcut(
            key: "k",
            modifiers: [.command, .shift],
            virtualKeyCode: 40
        )

        let renamed = original.renamed(to: "Open Agent Window")

        XCTAssertEqual(renamed.displayName, "Open Agent Window")
        XCTAssertEqual(renamed.mainKeys, original.mainKeys)
        XCTAssertEqual(renamed.modifiers, original.modifiers)
        XCTAssertEqual(renamed.virtualKeyCode, original.virtualKeyCode)
    }

    func testModifierOnlyShortcutRoundTripsWithoutInventingAMainKey() throws {
        let shortcut = KeyShortcut(
            mainKeys: [],
            modifiers: [.control, .shift]
        )
        let encoded = try JSONEncoder().encode(shortcut)

        XCTAssertFalse(shortcut.isEmpty)
        XCTAssertEqual(shortcut.key, "")
        XCTAssertEqual(try JSONDecoder().decode(KeyShortcut.self, from: encoded), shortcut)
    }

    func testShortcutNormalizesPressCountToSafeBounds() {
        XCTAssertEqual(KeyShortcut(key: "fn", pressCount: 0).pressCount, 1)
        XCTAssertEqual(KeyShortcut(key: "fn", pressCount: 8).pressCount, 4)
    }

    func testShortcutNormalizesTapIntervalToSafeBounds() {
        XCTAssertEqual(
            KeyShortcut(key: "fn", pressCount: 2, interTapIntervalMilliseconds: 5)
                .interTapIntervalMilliseconds,
            30
        )
        XCTAssertEqual(
            KeyShortcut(key: "fn", pressCount: 2, interTapIntervalMilliseconds: 2_000)
                .interTapIntervalMilliseconds,
            1_000
        )
    }

    func testShortcutDecodesConfigurationWrittenBeforePressCountWasAdded() throws {
        let data = Data(#"{"key":"d","modifiers":["control","shift"]}"#.utf8)

        let shortcut = try JSONDecoder().decode(KeyShortcut.self, from: data)

        XCTAssertEqual(shortcut.pressCount, 1)
        XCTAssertEqual(shortcut.interTapIntervalMilliseconds, 120)
    }

    func testTapPlannerPlacesConfiguredDelayOnlyBetweenTaps() {
        let shortcut = KeyShortcut(
            key: "fn",
            pressCount: 2,
            interTapIntervalMilliseconds: 175
        )

        let steps = KeyShortcutTapPlanner().steps(for: shortcut)

        XCTAssertEqual(
            steps,
            [.keyDown, .keyUp, .wait(milliseconds: 175), .keyDown, .keyUp]
        )
    }

    func testSingleTapPlanDoesNotWait() {
        let shortcut = KeyShortcut(key: "return", interTapIntervalMilliseconds: 500)

        XCTAssertEqual(
            KeyShortcutTapPlanner().steps(for: shortcut),
            [.keyDown, .keyUp]
        )
    }
}
