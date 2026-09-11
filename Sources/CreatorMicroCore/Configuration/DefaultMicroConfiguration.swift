extension MicroConfiguration {
    public static var `default`: MicroConfiguration {
        return MicroConfiguration(
            microphoneLayout: .separate,
            layers: [
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
                ),
                desktopLayer,
                agentsLayer,
                windowsLayer,
                meetingsLayer,
                snippetsLayer,
            ]
        )
    }

    private static var desktopLayer: LayerConfiguration {
        LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [
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
                .agent1: .pointer(.click(.primary)),
                .agent2: .escapeKey,
                .agent3: .switchWindow(.next),
                .agent4: .switchApplication(.previous),
                .agent5: .deleteKey,
            ],
            joystick: LayerJoystickConfiguration(mode: .arrowKeys)
        )
    }

    private static var agentsLayer: LayerConfiguration {
        var bindings = commonBindings(dictationProvider: .rede)
        let controls: [ControlID] = [.agent0, .agent1, .agent2, .agent3, .agent4, .agent5]
        for (index, control) in controls.enumerated() {
            bindings[control] = .agentFocus(sessionID: "slot-\(index + 1)")
        }
        return LayerConfiguration(id: .agents, name: "Agents", bindings: bindings)
    }

    private static var windowsLayer: LayerConfiguration {
        var bindings = commonBindings(dictationProvider: .rede)
        bindings.merge([
            .agent0: .switchApplication(.next),
            .agent1: .pointer(.click(.primary)),
            .agent2: .switchWindow(.next),
            .agent3: .switchWindow(.previous),
            .agent4: .switchApplication(.previous),
        ]) { _, specific in specific }
        return LayerConfiguration(id: .windows, name: "Windows", bindings: bindings)
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
        var bindings = commonBindings(dictationProvider: .rede)
        bindings.merge([
            .agent0: .textSnippet("Please continue."),
            .agent1: .textSnippet("Run the tests."),
            .agent2: .textSnippet("Summarize the current status."),
            .agent3: .textSnippet("Fix the root cause."),
            .agent4: .textSnippet("Review these changes."),
            .agent5: .textSnippet("Ship it."),
        ]) { _, specific in specific }
        return LayerConfiguration(id: .snippets, name: "Snippets", bindings: bindings)
    }

    private static func commonBindings(
        dictationProvider: DictationProviderID
    ) -> [ControlID: CreatorAction] {
        [
            .action6: .openTerminal,
            .action7: .openFinder,
            .action8: .inputMute(.toggle),
            .action9: .layer(.next),
            .action10: .dictation(
                DictationBinding(providerID: dictationProvider, behavior: .toggle)
            ),
            .action11: .approval,
            .action12: .returnKey,
            .encoderClockwise: .volume(.increase),
            .encoderCounterClockwise: .volume(.decrease),
            .encoderPress: .outputMute(.toggle),
        ]
    }
}
