import XCTest

@testable import CreatorMicroCore

final class LayerPresetConfigurationTests: XCTestCase {
    func testDefaultWorkflowPresetsPassConfigurationValidation() {
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(.default))
    }

    func testDefaultPresetOrderIsIndependentFromTheExpandedCatalog() {
        XCTAssertEqual(
            MicroLayerPresetCatalog.defaultPresetOrder,
            [
                .desktop,
                .claudeCodeCLI,
                .claudeApp,
                .codexCLI,
                .codexApp,
                .cursor,
                .meetings,
                .agentFocus,
                .windowManagement,
                .snippets,
            ]
        )
        XCTAssertEqual(MicroLayerPresetCatalog.all.count, 12)
        XCTAssertEqual(MicroLayerPresetCatalog.all.map(\.id), MicroLayerPresetID.allCases)
        XCTAssertTrue(MicroLayerPresetCatalog.all.allSatisfy { !$0.name.isEmpty })
        XCTAssertTrue(MicroLayerPresetCatalog.all.allSatisfy { !$0.detail.isEmpty })
    }

    func testDefaultConfigurationProvidesTenNamedWorkflowPresets() {
        XCTAssertEqual(
            MicroConfiguration.default.layers.map(\.name),
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
    }

    func testDesktopPresetUsesTheEstablishedDesktopControlPattern() throws {
        let desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))

        XCTAssertEqual(desktop.action(for: .agent0), .inputMute(.toggle))
        XCTAssertEqual(desktop.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(desktop.action(for: .agent2), .escapeKey)
        XCTAssertEqual(desktop.action(for: .agent3), .switchApplication(.next))
        XCTAssertEqual(
            desktop.action(for: .agent4),
            .shortOrLongPress(shortPress: .copy, longPress: .paste)
        )
        XCTAssertEqual(desktop.action(for: .agent5), .deleteKey)
        XCTAssertEqual(desktop.action(for: .action8), .slashCommand(command: "/", submit: false))
        XCTAssertEqual(desktop.action(for: .action11), .inputMute(.toggle))
        XCTAssertEqual(desktop.joystick?.mode, .arrowKeys)
    }

    func testClaudeCodeCLIPresetUsesOfficialInteractiveControls() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.claudeCodeCLI))

        XCTAssertEqual(layer.action(for: .agent0), .escapeKey)
        XCTAssertEqual(
            layer.action(for: .agent1),
            shortcut("tab", modifiers: [.shift], name: "Permission Mode")
        )
        XCTAssertEqual(
            layer.action(for: .agent2),
            shortcut("o", modifiers: [.control], name: "Transcript")
        )
        XCTAssertEqual(layer.action(for: .agent3), command("/status"))
        XCTAssertEqual(layer.action(for: .agent4), command("/context"))
        XCTAssertEqual(layer.action(for: .agent5), command("/tasks"))
    }

    func testClaudeAppPresetUsesSafeNativeAndClipboardControls() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.claudeApp))

        XCTAssertEqual(
            layer.action(for: .agent0),
            shortcut("n", modifiers: [.command], name: "New Chat")
        )
        XCTAssertEqual(
            layer.action(for: .agent1),
            shortcut("k", modifiers: [.command], name: "Command Palette")
        )
        XCTAssertEqual(layer.action(for: .agent2), .copy)
        XCTAssertEqual(layer.action(for: .agent3), .paste)
        XCTAssertEqual(
            layer.action(for: .agent4),
            shortcut("f", modifiers: [.command], name: "Find")
        )
        XCTAssertEqual(layer.action(for: .agent5), .escapeKey)
    }

    func testCodexCLIPresetProvidesOnlyCodexTerminalCommands() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.codexCLI))
        let commands = ["/status", "/diff", "/review", "/project", "/worktree", "/compact"]

        for (control, command) in zip(agentControls, commands) {
            XCTAssertEqual(layer.action(for: control), self.command(command))
        }
    }

    func testCodexAppPresetProvidesNativeAndWorkspaceControls() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.codexApp))

        XCTAssertEqual(
            layer.action(for: .agent0),
            shortcut("n", modifiers: [.command], name: "New Chat")
        )
        XCTAssertEqual(
            layer.action(for: .agent1),
            shortcut("k", modifiers: [.command], name: "Command Palette")
        )
        XCTAssertEqual(layer.action(for: .agent2), .openTerminal)
        XCTAssertEqual(layer.action(for: .agent3), command("/project"))
        XCTAssertEqual(layer.action(for: .agent4), command("/worktree"))
        XCTAssertEqual(layer.action(for: .agent5), command("/side"))
    }

    func testCursorPresetUsesLayoutSafeEditorControls() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.cursor))

        XCTAssertEqual(
            layer.action(for: .agent0),
            shortcut("i", modifiers: [.command], name: "Agent")
        )
        XCTAssertEqual(
            layer.action(for: .agent1),
            shortcut("n", modifiers: [.command], name: "New Chat")
        )
        XCTAssertEqual(layer.action(for: .agent2), .copy)
        XCTAssertEqual(layer.action(for: .agent3), .paste)
        XCTAssertEqual(
            layer.action(for: .agent4),
            shortcut("return", modifiers: [.control], name: "Submit")
        )
        XCTAssertEqual(
            layer.action(for: .agent5),
            shortcut("delete", modifiers: [.control, .shift], name: "Cancel Generation")
        )
    }

    func testMeetingsPresetRestoresUniversalAudioControls() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.meetingControls))

        XCTAssertEqual(layer.action(for: .agent0), .inputMute(.toggle))
        XCTAssertEqual(layer.action(for: .agent1), .outputMute(.toggle))
        XCTAssertEqual(layer.action(for: .agent2), .none)
        XCTAssertEqual(layer.action(for: .agent3), .none)
        XCTAssertEqual(layer.action(for: .agent4), .none)
        XCTAssertEqual(layer.action(for: .agent5), .none)
    }

    func testAgentFocusPresetRestoresSixSessionSlots() throws {
        let layer = try XCTUnwrap(MicroConfiguration.default.layer(.agentFocus))

        for (index, control) in agentControls.enumerated() {
            XCTAssertEqual(layer.action(for: control), .agentFocus(sessionID: "slot-\(index + 1)"))
        }
    }

    func testCatalogIncludesDistinctSwapInPresets() throws {
        XCTAssertEqual(
            Array(MicroLayerPresetCatalog.all.suffix(4).map(\.id)),
            [.browser, .windowManagement, .writing, .snippets]
        )

        let chassis = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        let browser = layer(for: .browser, chassis: chassis)
        let windows = layer(for: .windowManagement, chassis: chassis)
        let writing = layer(for: .writing, chassis: chassis)
        let snippets = layer(for: .snippets, chassis: chassis)

        XCTAssertEqual(
            browser.action(for: .agent0),
            shortcut("l", modifiers: [.command], name: "Address Bar")
        )
        XCTAssertEqual(windows.action(for: .agent0), .switchApplication(.next))
        XCTAssertEqual(writing.action(for: .agent0), .copy)
        XCTAssertEqual(snippets.action(for: .agent0), .textSnippet("Please continue."))
        XCTAssertNotEqual(browser.bindings, windows.bindings)
        XCTAssertNotEqual(windows.bindings, writing.bindings)
        XCTAssertNotEqual(writing.bindings, snippets.bindings)
    }

    func testEveryPresetKeepsDesktopChassisAndDedicatedMute() throws {
        var desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        desktop.assign(.pastePlainText, to: .action6)
        desktop.assign(.none, to: .action11)

        for preset in MicroLayerPresetCatalog.all {
            let layer = preset.layer(for: .cursor, desktopChassis: desktop)
            XCTAssertEqual(layer.action(for: .action6), .pastePlainText)
            XCTAssertEqual(layer.action(for: .action11), .inputMute(.toggle))
            XCTAssertEqual(layer.joystick, desktop.joystick)
        }
    }

    func testApplyingPresetChangesOnlyTheRequestedSlot() throws {
        var configuration = MicroConfiguration.default
        let originalDesktop = try XCTUnwrap(configuration.layer(.desktop))
        let originalCodexCLI = try XCTUnwrap(configuration.layer(.codexCLI))

        configuration.applyPreset(.snippets, to: .cursor)

        XCTAssertEqual(configuration.layer(.desktop), originalDesktop)
        XCTAssertEqual(configuration.layer(.codexCLI), originalCodexCLI)
        XCTAssertEqual(configuration.layer(.cursor)?.name, "Snippets")
        XCTAssertEqual(
            configuration.layer(.cursor)?.action(for: .agent5),
            .textSnippet("Ship it.")
        )
    }

    private func layer(
        for presetID: MicroLayerPresetID,
        chassis: LayerConfiguration
    ) -> LayerConfiguration {
        MicroLayerPresetCatalog.preset(for: presetID).layer(
            for: .cursor,
            desktopChassis: chassis
        )
    }

    private func command(_ value: String) -> CreatorAction {
        .slashCommand(command: value, submit: true)
    }

    private func shortcut(
        _ key: String,
        modifiers: [KeyboardModifier],
        name: String? = nil
    ) -> CreatorAction {
        .keyboardShortcut(
            KeyShortcut(key: key, modifiers: modifiers, displayName: name)
        )
    }

    private var agentControls: [ControlID] {
        [.agent0, .agent1, .agent2, .agent3, .agent4, .agent5]
    }
}
