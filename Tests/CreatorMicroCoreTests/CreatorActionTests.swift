import Foundation
import XCTest

@testable import CreatorMicroCore

final class CreatorActionTests: XCTestCase {
    func testEveryAssignableActionRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for action in assignableActions {
            let data = try encoder.encode(action)
            let decoded = try decoder.decode(CreatorAction.self, from: data)
            XCTAssertEqual(decoded, action)
        }
    }

    private var assignableActions: [CreatorAction] {
        [
            .none,
            .dictation(DictationBinding(providerID: .chatGPTCodex, behavior: .toggle)),
            .approval,
            .returnKey,
            .escapeKey,
            .deleteKey,
            .openTerminal,
            .openFinder,
            .openApplication(bundleIdentifier: "com.apple.Safari"),
            .switchApplication(.next),
            .switchWindow(.previous),
            .layer(.next),
            .layer(.previous),
            .layer(.select(.meetings)),
            .shortOrLongPress(
                shortPress: .openFinder,
                longPress: .openTerminal
            ),
            .textSnippet("Hello, world!"),
            .copy,
            .paste,
            .pastePlainText,
            .keyboardShortcut(
                KeyShortcut(key: "k", modifiers: [.command, .shift])
            ),
            .slashCommand(command: "/review", submit: false),
            .slashCommand(command: "/compact", submit: true),
            .actionSequence([.copy, .pastePlainText, .returnKey]),
            .volume(.increase),
            .volume(.decrease),
            .volume(.set(0.42)),
            .outputMute(.toggle),
            .inputMute(.mute),
            .pointer(.move(horizontal: 12, vertical: -4)),
            .pointer(.click(.secondary)),
            .pointer(.scroll(.down)),
            .appleScript("tell application \"Finder\" to activate"),
            .shellCommand("open -a Terminal"),
            .agentFocus(sessionID: "codex-1"),
            .focusNextAgent,
        ]
    }

    func testLegacyActionJSONWithoutDualBindingStillDecodes() throws {
        let data = Data(#"{"openFinder":{}}"#.utf8)

        XCTAssertEqual(
            try JSONDecoder().decode(CreatorAction.self, from: data),
            .openFinder
        )
    }

    func testDeleteActionUsesStableCodableRepresentation() throws {
        let data = try JSONEncoder().encode(CreatorAction.deleteKey)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"deleteKey":{}}"#)
        XCTAssertEqual(
            try JSONDecoder().decode(CreatorAction.self, from: Data(#"{"deleteKey":{}}"#.utf8)),
            .deleteKey
        )
    }
}
