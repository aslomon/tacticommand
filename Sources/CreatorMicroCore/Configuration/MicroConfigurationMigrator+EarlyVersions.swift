extension MicroConfigurationMigrator {
    static func migrateVersionOne(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        migrateLayerKeyDefaults(in: &migrated)
        migratePointerClickDefaults(in: &migrated)
        migrated.schemaVersion = 2
        return migrated
    }

    static func migrateVersionTwo(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        migrateDesktopGeometryDefaults(in: &migrated)
        migrated.schemaVersion = 3
        return migrated
    }

    static func migrateVersionThree(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        migrateDesktopJoystickDefault(in: &migrated)
        migrated.schemaVersion = 4
        return migrated
    }

    static func migrateVersionFour(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        migrateLegacyCodexAudioDefaults(in: &migrated)
        migrated.schemaVersion = 5
        return migrated
    }

    private static func migrateLegacyCodexAudioDefaults(
        in configuration: inout MicroConfiguration
    ) {
        guard
            configuration.layer(.codex)?.bindings
                == [.action9: .layer(.next)]
        else {
            return
        }
        for (control, action) in audioDefaults
        where configuration.layer(.codex)?.bindings[control] == nil {
            configuration.assign(action: action, to: control, on: .codex)
        }
    }

    private static let audioDefaults: [ControlID: CreatorAction] = [
        .action8: .inputMute(.toggle),
        .encoderClockwise: .volume(.increase),
        .encoderCounterClockwise: .volume(.decrease),
        .encoderPress: .outputMute(.toggle),
    ]

    private static func migrateDesktopJoystickDefault(
        in configuration: inout MicroConfiguration
    ) {
        let inherited = LayerJoystickConfiguration(
            inheriting: configuration.joystick,
            mode: .arrowKeys
        )
        guard let existing = configuration.layer(.desktop)?.joystick else {
            configuration.setJoystick(inherited, on: .desktop)
            return
        }
        guard existing.mode != .off else { return }
        configuration.setJoystick(
            LayerJoystickConfiguration(
                mode: .arrowKeys,
                deadZone: existing.deadZone,
                maximumSpeed: existing.maximumSpeed
            ),
            on: .desktop
        )
    }

    private static func migrateDesktopGeometryDefaults(
        in configuration: inout MicroConfiguration
    ) {
        let oldClick = CreatorAction.shortOrLongPress(
            shortPress: .pointer(.click(.primary)),
            longPress: .pointer(.click(.secondary))
        )
        replace(
            oldClick,
            with: .pointer(.click(.primary)),
            control: .agent1,
            layer: .desktop,
            in: &configuration
        )
        replace(.none, with: .escapeKey, control: .agent2, layer: .desktop, in: &configuration)
        replace(.escapeKey, with: .deleteKey, control: .agent5, layer: .desktop, in: &configuration)
    }

    private static func migrateLayerKeyDefaults(
        in configuration: inout MicroConfiguration
    ) {
        for layer in LayerIndex.all {
            let oldAction: CreatorAction =
                layer == .codex || layer == .meetings
                ? .none
                : .switchApplication(.next)
            replace(
                oldAction,
                with: .layer(.next),
                control: .action9,
                layer: layer,
                in: &configuration
            )
        }
    }

    private static func migratePointerClickDefaults(
        in configuration: inout MicroConfiguration
    ) {
        replace(.pointer(.click(.primary)), with: .none, control: .agent0, layer: .desktop, in: &configuration)
        replace(
            .pointer(.click(.secondary)), with: .pointer(.click(.primary)), control: .agent1, layer: .desktop,
            in: &configuration)
        replace(.pointer(.click(.middle)), with: .none, control: .agent2, layer: .desktop, in: &configuration)
        replace(
            .switchApplication(.previous), with: .pointer(.click(.primary)), control: .agent1, layer: .windows,
            in: &configuration)
        replace(
            .pointer(.click(.primary)), with: .switchApplication(.previous), control: .agent4, layer: .windows,
            in: &configuration)
        replace(.pointer(.click(.secondary)), with: .none, control: .agent5, layer: .windows, in: &configuration)
    }

    private static func replace(
        _ oldAction: CreatorAction,
        with newAction: CreatorAction,
        control: ControlID,
        layer: LayerIndex,
        in configuration: inout MicroConfiguration
    ) {
        guard configuration.layer(layer)?.action(for: control) == oldAction else { return }
        configuration.assign(action: newAction, to: control, on: layer)
    }
}
