extension MicroConfiguration {
    public static var `default`: MicroConfiguration {
        let chassis = defaultDesktopChassis
        let layers = zip(
            LayerIndex.all,
            MicroLayerPresetCatalog.defaultPresetOrder
        ).map {
            layer, presetID in
            MicroLayerPresetCatalog.preset(for: presetID).layer(
                for: layer,
                desktopChassis: chassis
            )
        }
        return MicroConfiguration(
            microphoneLayout: .separate,
            layers: layers
        )
    }

    private static var defaultDesktopChassis: LayerConfiguration {
        LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [
                .action6: .openTerminal,
                .action7: .openFinder,
                .action8: .slashCommand(command: "/", submit: false),
                .action9: .layer(.next),
                .action10: .dictation(
                    DictationBinding(providerID: .rede, behavior: .toggle)
                ),
                .action11: .inputMute(.toggle),
                .action12: .returnKey,
                .encoderClockwise: .volume(.increase),
                .encoderCounterClockwise: .volume(.decrease),
                .encoderPress: .outputMute(.toggle),
            ],
            joystick: LayerJoystickConfiguration(mode: .arrowKeys)
        )
    }
}
