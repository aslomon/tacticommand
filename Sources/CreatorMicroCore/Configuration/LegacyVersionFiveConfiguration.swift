enum LegacyVersionFiveConfiguration {
    static func layer(_ id: LayerIndex) -> LayerConfiguration {
        switch id {
        case .codex:
            codexLayer
        case .desktop:
            desktopLayer
        case .agents:
            agentsLayer
        case .windows:
            windowsLayer
        case .meetings:
            meetingsLayer
        default:
            snippetsLayer
        }
    }

    private static var codexLayer: LayerConfiguration {
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

    private static var desktopLayer: LayerConfiguration {
        LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: commonBindings().merging([
                .agent1: .pointer(.click(.primary)),
                .agent2: .escapeKey,
                .agent3: .switchWindow(.next),
                .agent4: .switchApplication(.previous),
                .agent5: .deleteKey,
            ]) { _, specific in specific },
            joystick: LayerJoystickConfiguration(mode: .arrowKeys)
        )
    }

    private static var agentsLayer: LayerConfiguration {
        var bindings = commonBindings()
        for (index, control) in agentControls.enumerated() {
            bindings[control] = .agentFocus(sessionID: "slot-\(index + 1)")
        }
        return LayerConfiguration(id: .agents, name: "Agents", bindings: bindings)
    }

    private static var windowsLayer: LayerConfiguration {
        LayerConfiguration(
            id: .windows,
            name: "Windows",
            bindings: commonBindings().merging([
                .agent0: .switchApplication(.next),
                .agent1: .pointer(.click(.primary)),
                .agent2: .switchWindow(.next),
                .agent3: .switchWindow(.previous),
                .agent4: .switchApplication(.previous),
            ]) { _, specific in specific }
        )
    }

    private static var meetingsLayer: LayerConfiguration {
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

    private static var snippetsLayer: LayerConfiguration {
        let snippets = [
            "Please continue.",
            "Run the tests.",
            "Summarize the current status.",
            "Fix the root cause.",
            "Review these changes.",
            "Ship it.",
        ]
        var bindings = commonBindings()
        for (index, control) in agentControls.enumerated() {
            bindings[control] = .textSnippet(snippets[index])
        }
        return LayerConfiguration(id: .snippets, name: "Snippets", bindings: bindings)
    }

    private static func commonBindings() -> [ControlID: CreatorAction] {
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

    private static let agentControls: [ControlID] = [
        .agent0, .agent1, .agent2, .agent3, .agent4, .agent5,
    ]
}
