import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class ActionPresentationTests: XCTestCase {
    func testDeleteActionIsSelectableAsBackwardDelete() {
        XCTAssertEqual(ActionKind(action: .deleteKey), .deleteKey)
        XCTAssertEqual(ActionKind.deleteKey.makeAction(current: .none), .deleteKey)
        XCTAssertEqual(ActionKind.deleteKey.title, "Delete")
        XCTAssertEqual(ActionKind.deleteKey.symbol, "delete.left")
    }

    func testPointerMoveIsNeverPresentedAsAClick() {
        let action = CreatorAction.pointer(.move(horizontal: 12, vertical: -8))

        XCTAssertEqual(ActionKind(action: action), .pointerMove)
    }

    func testPointerMoveSelectionCreatesANudgeAction() {
        let action = ActionKind.pointerMove.makeAction(current: .none)

        XCTAssertEqual(action, .pointer(.move(horizontal: 24, vertical: 0)))
    }

    func testLayerActionsHaveDistinctAssignablePresentation() {
        XCTAssertEqual(ActionKind(action: .layer(.next)), .nextLayer)
        XCTAssertEqual(ActionKind(action: .layer(.previous)), .previousLayer)
        XCTAssertEqual(ActionKind(action: .layer(.select(.meetings))), .selectLayer)
        XCTAssertEqual(ActionKind.selectLayer.title, "Select Layer…")
    }

    func testDirectLayerSelectionKeepsItsExistingTarget() {
        let current = CreatorAction.layer(.select(.snippets))

        XCTAssertEqual(ActionKind.selectLayer.makeAction(current: current), current)
    }

    func testClipboardAndSlashCommandsAreFirstClassActions() {
        XCTAssertEqual(ActionKind(action: .copy), .copy)
        XCTAssertEqual(ActionKind(action: .paste), .paste)
        XCTAssertEqual(
            ActionKind(action: .slashCommand(command: "/review", submit: true)),
            .slashCommand
        )
        XCTAssertEqual(ActionKind.copy.title, "Copy")
        XCTAssertEqual(ActionKind.paste.title, "Paste")
        XCTAssertEqual(ActionKind(action: .pastePlainText), .pastePlainText)
        XCTAssertEqual(ActionKind.pastePlainText.title, "Paste as Plain Text")
        XCTAssertEqual(ActionKind.slashCommand.title, "Slash Command")
    }

    func testTeamRecommendedActionsAreFirstClassActions() {
        let shortcut = KeyShortcut(key: "k", modifiers: [.command])

        XCTAssertEqual(ActionKind(action: .keyboardShortcut(shortcut)), .keyboardShortcut)
        XCTAssertEqual(ActionKind(action: .actionSequence([.copy, .paste])), .actionSequence)
        XCTAssertEqual(ActionKind(action: .focusNextAgent), .focusNextAgent)
        XCTAssertEqual(
            ActionKind.keyboardShortcut.makeAction(current: .none),
            .keyboardShortcut(KeyShortcut(key: "k", modifiers: [.command]))
        )
    }

    func testNamedKeyboardShortcutUsesItsNameAsTheActionLabel() {
        let action = CreatorAction.keyboardShortcut(
            KeyShortcut(
                key: "k",
                modifiers: [.command, .shift],
                displayName: "Open Agent Window"
            )
        )

        XCTAssertEqual(action.actionTitle, "Open Agent Window")
        XCTAssertEqual(ActionKind(action: action).title, "Keyboard Shortcut")
    }

    func testUnnamedKeyboardShortcutUsesTheFormattedChordAsTheActionLabel() {
        let action = CreatorAction.keyboardShortcut(
            KeyShortcut(key: "k", modifiers: [.command, .shift])
        )

        XCTAssertEqual(action.actionTitle, "shift + cmd + K")
    }

    func testSlashCommandSelectionKeepsItsExistingConfiguration() {
        let current = CreatorAction.slashCommand(command: "/review", submit: true)

        XCTAssertEqual(ActionKind.slashCommand.makeAction(current: current), current)
        XCTAssertEqual(
            ActionKind.slashCommand.makeAction(current: .none),
            .slashCommand(command: "/", submit: false)
        )
    }

    func testSlashCommandUsesItsCommandAsTheKeyLabel() {
        XCTAssertEqual(
            CreatorAction.slashCommand(command: "/status", submit: true).actionTitle,
            "/status"
        )
        XCTAssertEqual(
            CreatorAction.slashCommand(command: "/", submit: false).actionTitle,
            "/"
        )
    }

    func testDualPressEditorWrapsUpdatesAndUnwrapsWithoutNesting() {
        let wrapped = ShortOrLongPressBindingEditor.replacingLongPress(
            in: .openFinder,
            with: .openTerminal
        )

        XCTAssertEqual(
            wrapped,
            .shortOrLongPress(
                shortPress: .openFinder,
                longPress: .openTerminal
            )
        )
        XCTAssertEqual(
            ShortOrLongPressBindingEditor.replacingShortPress(
                in: wrapped,
                with: .returnKey
            ),
            .shortOrLongPress(
                shortPress: .returnKey,
                longPress: .openTerminal
            )
        )
        XCTAssertEqual(
            ShortOrLongPressBindingEditor.replacingLongPress(
                in: wrapped,
                with: nil
            ),
            .openFinder
        )
    }

    func testParameterizedActionsReplaceOnlyTheShortPressBranch() {
        let longPress = CreatorAction.openTerminal

        for replacement in Self.parameterizedActions {
            let action = ShortOrLongPressBindingEditor.replacingShortPress(
                in: .shortOrLongPress(shortPress: .openFinder, longPress: longPress),
                with: replacement
            )

            XCTAssertEqual(
                action,
                .shortOrLongPress(shortPress: replacement, longPress: longPress)
            )
        }
    }

    func testParameterizedActionsReplaceOnlyTheLongPressBranch() {
        let shortPress = CreatorAction.returnKey

        for replacement in Self.parameterizedActions {
            let action = ShortOrLongPressBindingEditor.replacingLongPress(
                in: .shortOrLongPress(shortPress: shortPress, longPress: .openFinder),
                with: replacement
            )

            XCTAssertEqual(
                action,
                .shortOrLongPress(shortPress: shortPress, longPress: replacement)
            )
        }
    }

    func testDualPressEditorRejectsNestedBranchReplacements() {
        let original = CreatorAction.shortOrLongPress(
            shortPress: .openFinder,
            longPress: .openTerminal
        )
        let nested = CreatorAction.shortOrLongPress(
            shortPress: .returnKey,
            longPress: .escapeKey
        )

        XCTAssertEqual(
            ShortOrLongPressBindingEditor.replacingShortPress(in: original, with: nested),
            original
        )
        XCTAssertEqual(
            ShortOrLongPressBindingEditor.replacingLongPress(in: original, with: nested),
            original
        )
    }

    func testDictationEditorReplacesShortcutWithoutLosingOtherParameters() {
        let original = DictationBinding(
            providerID: .rede,
            behavior: .holdToTalk,
            shortcut: nil
        )
        let shortcut = KeyShortcut(key: "space", modifiers: [.option])

        XCTAssertEqual(
            DictationBindingEditor.replacingShortcut(shortcut, in: original),
            DictationBinding(
                providerID: .rede,
                behavior: .holdToTalk,
                shortcut: shortcut
            )
        )
    }

    func testDictationEditorNormalizesBehaviorWhenProviderChanges() {
        let original = DictationBinding(
            providerID: .rede,
            behavior: .holdToTalk,
            shortcut: KeyShortcut(key: "r", modifiers: [.control])
        )
        let provider = BuiltInDictationProvider.chatGPTCodex.definition(
            availability: .available
        )

        XCTAssertEqual(
            DictationBindingEditor.choosing(provider, from: original),
            DictationBinding(
                providerID: .chatGPTCodex,
                behavior: .toggle,
                shortcut: provider.defaultShortcut
            )
        )
    }

    private static var parameterizedActions: [CreatorAction] {
        [
            .dictation(
                DictationBinding(
                    providerID: .chatGPTCodex,
                    behavior: .toggle,
                    shortcut: KeyShortcut(key: "d", modifiers: [.control, .shift])
                )
            ),
            .openApplication(bundleIdentifier: "com.example.Editor"),
            .layer(.select(.meetings)),
            .switchApplication(.previous),
            .switchWindow(.previous),
            .outputMute(.mute),
            .inputMute(.unmute),
            .volume(.set(0.72)),
            .pointer(.move(horizontal: -37, vertical: 14)),
            .textSnippet("Ship it"),
            .slashCommand(command: "/review", submit: true),
            .appleScript("return 42"),
            .shellCommand("pwd"),
            .agentFocus(sessionID: "slot-6"),
        ]
    }
}
