import Foundation
import XCTest

@testable import CreatorMicroCore

final class AppConfigurationTests: XCTestCase {
    func testDefaultConfigurationContainsTenNamedSoftwareLayersInDisplayOrder() {
        let configuration = MicroConfiguration.default

        XCTAssertEqual(configuration.layers.count, 10)
        XCTAssertEqual(
            configuration.layers.map(\.name),
            [
                "Desktop",
                "Claude Code CLI",
                "Claude App",
                "Codex CLI",
                "Codex App",
                "Cursor",
                "Meetings",
                "Agent Focus",
                "Window Management",
                "Snippets",
            ]
        )
        XCTAssertEqual(configuration.microphoneLayout, .separate)
    }

    func testDesktopLayerProvidesTheRequestedCoreControls() throws {
        let configuration = MicroConfiguration.default
        let desktop = try XCTUnwrap(configuration.layer(.desktop))

        XCTAssertEqual(desktop.action(for: .action6), .openTerminal)
        XCTAssertEqual(desktop.action(for: .action7), .openFinder)
        XCTAssertEqual(desktop.action(for: .action8), .slashCommand(command: "/", submit: false))
        XCTAssertEqual(desktop.action(for: .action9), .layer(.next))
        XCTAssertEqual(
            desktop.action(for: .action10),
            .dictation(DictationBinding(providerID: .rede, behavior: .toggle))
        )
        XCTAssertEqual(desktop.action(for: .action11), .inputMute(.toggle))
        XCTAssertEqual(desktop.action(for: .action12), .returnKey)
        XCTAssertEqual(desktop.action(for: .encoderClockwise), .volume(.increase))
        XCTAssertEqual(desktop.action(for: .encoderCounterClockwise), .volume(.decrease))
        XCTAssertEqual(desktop.action(for: .encoderPress), .outputMute(.toggle))
        XCTAssertEqual(desktop.action(for: .agent0), .inputMute(.toggle))
        XCTAssertEqual(desktop.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(desktop.action(for: .agent2), .escapeKey)
        XCTAssertEqual(desktop.action(for: .agent3), .switchApplication(.next))
        XCTAssertEqual(
            desktop.action(for: .agent4),
            .shortOrLongPress(shortPress: .copy, longPress: .paste)
        )
        XCTAssertEqual(desktop.action(for: .agent5), .deleteKey)
    }

    func testEveryDefaultLayerProvidesDedicatedAudioControls() {
        for layer in MicroConfiguration.default.layers {
            XCTAssertEqual(layer.action(for: .action11), .inputMute(.toggle))
            XCTAssertEqual(layer.action(for: .encoderClockwise), .volume(.increase))
            XCTAssertEqual(layer.action(for: .encoderCounterClockwise), .volume(.decrease))
            XCTAssertEqual(layer.action(for: .encoderPress), .outputMute(.toggle))
        }
    }

    func testCodexCLILayerMapsSixTerminalCommands() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.codexCLI))
        let commands = ["/status", "/diff", "/review", "/project", "/worktree", "/compact"]

        for (index, control) in agentControls.enumerated() {
            XCTAssertEqual(
                layer.action(for: control),
                .slashCommand(command: commands[index], submit: true)
            )
        }
        XCTAssertEqual(layer.action(for: .action6), .openTerminal)
        XCTAssertEqual(layer.action(for: .action9), .layer(.next))
        XCTAssertEqual(layer.action(for: .action12), .returnKey)
    }

    func testCodexAppLayerProvidesAppAndWorkspaceControls() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.codexApp))

        XCTAssertEqual(
            layer.action(for: .agent0),
            .keyboardShortcut(
                KeyShortcut(key: "n", modifiers: [.command], displayName: "New Chat")
            )
        )
        XCTAssertEqual(
            layer.action(for: .agent3),
            .slashCommand(command: "/project", submit: true)
        )
        XCTAssertEqual(
            layer.action(for: .agent5),
            .slashCommand(command: "/side", submit: true)
        )
    }

    func testSecondaryAndMiddleClicksRemainAssignableButAreNotDefaults() {
        let configuredActions = MicroConfiguration.default.layers.flatMap {
            $0.bindings.values
        }

        XCTAssertFalse(configuredActions.contains(.pointer(.click(.secondary))))
        XCTAssertFalse(configuredActions.contains(.pointer(.click(.middle))))
    }

    func testEveryDefaultLayerCanAdvanceFromThePhysicalActionNineKey() {
        for layer in MicroConfiguration.default.layers {
            XCTAssertEqual(layer.action(for: .action9), .layer(.next))
        }
    }

    func testCursorLayerHasEditorAndClipboardWorkflowActions() throws {
        let snippets = try XCTUnwrap(MicroConfiguration.default.layer(.cursor))

        XCTAssertEqual(
            snippets.action(for: .agent0),
            .keyboardShortcut(KeyShortcut(key: "i", modifiers: [.command], displayName: "Agent"))
        )
        XCTAssertEqual(
            snippets.action(for: .agent1),
            .keyboardShortcut(KeyShortcut(key: "n", modifiers: [.command], displayName: "New Chat"))
        )
        XCTAssertEqual(snippets.action(for: .agent2), .copy)
        XCTAssertEqual(snippets.action(for: .agent3), .paste)
        XCTAssertEqual(
            snippets.action(for: .agent4),
            .keyboardShortcut(KeyShortcut(key: "return", modifiers: [.control], displayName: "Submit"))
        )
        XCTAssertEqual(
            snippets.action(for: .agent5),
            .keyboardShortcut(
                KeyShortcut(
                    key: "delete",
                    modifiers: [.control, .shift],
                    displayName: "Cancel Generation"
                )
            )
        )
    }

    func testConfigurationRoundTripsThroughJSON() throws {
        var configuration = MicroConfiguration.default
        configuration.assign(
            action: .textSnippet("Ship it"),
            to: .agent5,
            on: .cursor
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(MicroConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(
            decoded.layer(.cursor)?.action(for: .agent5),
            .textSnippet("Ship it")
        )
    }

    func testValidatorRejectsShortcutsBeyondTheSafeChordLimit() {
        var configuration = MicroConfiguration.default
        let keys = (0...KeyShortcut.maximumMainKeyCount).map { index in
            KeyShortcutKey(key: "key-\(index)")
        }
        configuration.assign(
            action: .dictation(
                DictationBinding(
                    providerID: .rede,
                    behavior: .toggle,
                    shortcut: KeyShortcut(mainKeys: keys)
                )
            ),
            to: .action10,
            on: .desktop
        )

        XCTAssertThrowsError(try MicroConfigurationValidator.validate(configuration))
    }

    func testValidatorAcceptsModifierOnlyShortcutAndRejectsEmptyShortcut() {
        var modifierOnly = MicroConfiguration.default
        modifierOnly.assign(
            action: .dictation(
                DictationBinding(
                    providerID: .rede,
                    behavior: .toggle,
                    shortcut: KeyShortcut(
                        mainKeys: [],
                        modifiers: [.control, .shift]
                    )
                )
            ),
            to: .action10,
            on: .desktop
        )
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(modifierOnly))

        var empty = MicroConfiguration.default
        empty.assign(
            action: .dictation(
                DictationBinding(
                    providerID: .rede,
                    behavior: .toggle,
                    shortcut: KeyShortcut(mainKeys: [], modifiers: [])
                )
            ),
            to: .action10,
            on: .desktop
        )
        XCTAssertThrowsError(try MicroConfigurationValidator.validate(empty))
    }

    func testValidatorRejectsUnsafeShortcutDisplayNames() {
        var tooLong = MicroConfiguration.default
        tooLong.assign(
            action: .keyboardShortcut(
                KeyShortcut(key: "k", displayName: String(repeating: "x", count: 129))
            ),
            to: .agent0,
            on: .desktop
        )
        var controlCharacter = MicroConfiguration.default
        controlCharacter.assign(
            action: .keyboardShortcut(KeyShortcut(key: "k", displayName: "Open\nPalette")),
            to: .agent0,
            on: .desktop
        )

        XCTAssertThrowsError(try MicroConfigurationValidator.validate(tooLong))
        XCTAssertThrowsError(try MicroConfigurationValidator.validate(controlCharacter))
    }

    private var agentControls: [ControlID] {
        [.agent0, .agent1, .agent2, .agent3, .agent4, .agent5]
    }
}
