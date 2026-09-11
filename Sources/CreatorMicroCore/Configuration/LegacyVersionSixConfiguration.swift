enum LegacyVersionSixConfiguration {
    static func configuration(
        desktopChassis: LayerConfiguration
    ) -> MicroConfiguration {
        MicroConfiguration(
            schemaVersion: 6,
            microphoneLayout: .separate,
            layers: legacyLayerIDs.map { id in
                layer(id, desktopChassis: desktopChassis)
            }
        )
    }

    static func layer(
        _ id: LayerIndex,
        desktopChassis: LayerConfiguration
    ) -> LayerConfiguration {
        if id == .desktop { return desktopChassis }
        if id == .codex {
            return presetLayer(
                id: id,
                name: "Codex Terminal",
                desktopChassis: desktopChassis,
                overrides: codexTerminalOverrides
            )
        }
        if id == .agents {
            return presetLayer(
                id: id,
                name: "Codex Cloud",
                desktopChassis: desktopChassis,
                overrides: codexCloudOverrides
            )
        }
        if id == .windows {
            return presetLayer(
                id: id,
                name: "OpenAI Codex",
                desktopChassis: desktopChassis,
                overrides: codexAppOverrides
            )
        }
        if id == .meetings {
            return presetLayer(
                id: id,
                name: "Claude Code",
                desktopChassis: desktopChassis,
                overrides: claudeCodeOverrides
            )
        }
        return presetLayer(
            id: id,
            name: "Cursor",
            desktopChassis: desktopChassis,
            overrides: cursorOverrides
        )
    }

    private static func presetLayer(
        id: LayerIndex,
        name: String,
        desktopChassis: LayerConfiguration,
        overrides: [ControlID: CreatorAction]
    ) -> LayerConfiguration {
        var bindings = desktopChassis.bindings
        if bindings[.action11] == nil {
            bindings[.action11] = .inputMute(.toggle)
        }
        for control in agentControls {
            bindings.removeValue(forKey: control)
        }
        for (control, action) in overrides {
            bindings[control] = action
        }
        return LayerConfiguration(
            id: id,
            name: name,
            bindings: bindings,
            joystick: desktopChassis.joystick
        )
    }

    private static let codexTerminalOverrides: [ControlID: CreatorAction] = [
        .agent0: terminalWindow("n"),
        .agent1: terminalWindow("p"),
        .agent2: terminalWindow("c"),
        .agent3: command("/status"),
        .agent4: command("/diff"),
        .agent5: command("/review"),
    ]

    private static let codexCloudOverrides: [ControlID: CreatorAction] = [
        .agent0: command("/cloud"),
        .agent1: command("/cloud-environment"),
        .agent2: command("/local"),
        .agent3: command("/status"),
        .agent4: command("/diff"),
        .agent5: command("/review"),
    ]

    private static let codexAppOverrides: [ControlID: CreatorAction] = [
        .agent0: shortcut("n", [.command]),
        .agent1: shortcut("k", [.command]),
        .agent2: .openTerminal,
        .agent3: command("/project"),
        .agent4: command("/worktree"),
        .agent5: command("/side"),
    ]

    private static let claudeCodeOverrides: [ControlID: CreatorAction] = [
        .agent0: .escapeKey,
        .agent1: shortcut("tab", [.shift]),
        .agent2: shortcut("o", [.control]),
        .agent3: command("/status"),
        .agent4: command("/context"),
        .agent5: command("/tasks"),
    ]

    private static let cursorOverrides: [ControlID: CreatorAction] = [
        .agent0: shortcut("i", [.command]),
        .agent1: shortcut("n", [.command]),
        .agent2: .copy,
        .agent3: .paste,
        .agent4: shortcut("return", [.control]),
        .agent5: shortcut("delete", [.control, .shift]),
    ]

    private static let legacyLayerIDs: [LayerIndex] = [
        .codex, .desktop, .agents, .windows, .meetings, .snippets,
    ]

    private static let agentControls: [ControlID] = [
        .agent0, .agent1, .agent2, .agent3, .agent4, .agent5,
    ]

    private static func command(_ value: String) -> CreatorAction {
        .slashCommand(command: value, submit: true)
    }

    private static func shortcut(
        _ key: String,
        _ modifiers: [KeyboardModifier]
    ) -> CreatorAction {
        .keyboardShortcut(KeyShortcut(key: key, modifiers: modifiers))
    }

    private static func terminalWindow(_ key: String) -> CreatorAction {
        .actionSequence([
            shortcut("b", [.control]),
            shortcut(key, []),
        ])
    }
}
