@testable import CreatorMicroCore

enum WorkflowPresetMigrationFixtures {
    static func versionFiveConfiguration(
        desktop: LayerConfiguration
    ) -> MicroConfiguration {
        MicroConfiguration(
            schemaVersion: 5,
            microphoneLayout: .separate,
            layers: [
                legacyCodexLayer,
                desktop,
                legacyAgentsLayer,
                legacyWindowsLayer,
                legacyMeetingsLayer,
                legacySnippetsLayer,
            ]
        )
    }

    static func versionSevenConfigurationWithoutShortcutNames() -> MicroConfiguration {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 7
        legacy.layers.removeAll {
            $0.id == .windowManagement || $0.id == .snippetCommands
        }
        for layer in legacy.layers {
            for control in agentControls {
                guard case .keyboardShortcut(let shortcut) = layer.action(for: control) else {
                    continue
                }
                legacy.assign(
                    action: .keyboardShortcut(shortcut.renamed(to: nil)),
                    to: control,
                    on: layer.id
                )
            }
        }
        return legacy
    }

    static var legacyDesktopLayer: LayerConfiguration {
        LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: commonLegacyBindings().merging([
                .agent1: .pointer(.click(.primary)),
                .agent2: .escapeKey,
                .agent3: .switchWindow(.next),
                .agent4: .switchApplication(.previous),
                .agent5: .deleteKey,
            ]) { _, specific in specific },
            joystick: LayerJoystickConfiguration(mode: .arrowKeys)
        )
    }

    private static var legacyCodexLayer: LayerConfiguration {
        LayerConfiguration(
            id: .codex,
            name: "Codex",
            bindings: [
                .action8: .inputMute(.toggle),
                .action9: .layer(.next),
                .encoderClockwise: .volume(.increase),
                .encoderCounterClockwise: .volume(.decrease),
                .encoderPress: .outputMute(.toggle),
            ]
        )
    }

    private static var legacyAgentsLayer: LayerConfiguration {
        var bindings = commonLegacyBindings()
        for (index, control) in agentControls.enumerated() {
            bindings[control] = .agentFocus(sessionID: "slot-\(index + 1)")
        }
        return LayerConfiguration(id: .agents, name: "Agents", bindings: bindings)
    }

    private static var legacyWindowsLayer: LayerConfiguration {
        LayerConfiguration(
            id: .windows,
            name: "Windows",
            bindings: commonLegacyBindings().merging([
                .agent0: .switchApplication(.next),
                .agent1: .pointer(.click(.primary)),
                .agent2: .switchWindow(.next),
                .agent3: .switchWindow(.previous),
                .agent4: .switchApplication(.previous),
            ]) { _, specific in specific }
        )
    }

    private static var legacyMeetingsLayer: LayerConfiguration {
        LayerConfiguration(
            id: .meetings,
            name: "Meetings",
            bindings: [
                .agent0: .inputMute(.toggle),
                .agent1: .outputMute(.toggle),
                .action8: .inputMute(.toggle),
                .action9: .layer(.next),
                .action10: .dictation(
                    DictationBinding(providerID: .appleDictation, behavior: .toggle)
                ),
                .action11: .approval,
                .action12: .returnKey,
                .encoderClockwise: .volume(.increase),
                .encoderCounterClockwise: .volume(.decrease),
                .encoderPress: .outputMute(.toggle),
            ]
        )
    }

    private static var legacySnippetsLayer: LayerConfiguration {
        let snippets = [
            "Please continue.",
            "Run the tests.",
            "Summarize the current status.",
            "Fix the root cause.",
            "Review these changes.",
            "Ship it.",
        ]
        var bindings = commonLegacyBindings()
        for (index, control) in agentControls.enumerated() {
            bindings[control] = .textSnippet(snippets[index])
        }
        return LayerConfiguration(id: .snippets, name: "Snippets", bindings: bindings)
    }

    private static func commonLegacyBindings() -> [ControlID: CreatorAction] {
        [
            .action6: .openTerminal,
            .action7: .openFinder,
            .action8: .inputMute(.toggle),
            .action9: .layer(.next),
            .action10: .dictation(
                DictationBinding(providerID: .rede, behavior: .toggle)
            ),
            .action11: .approval,
            .action12: .returnKey,
            .encoderClockwise: .volume(.increase),
            .encoderCounterClockwise: .volume(.decrease),
            .encoderPress: .outputMute(.toggle),
        ]
    }

    private static var agentControls: [ControlID] {
        [.agent0, .agent1, .agent2, .agent3, .agent4, .agent5]
    }
}
