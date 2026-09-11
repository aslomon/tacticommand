extension MicroConfigurationMigrator {
    static func migrateVersionFive(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        if let desktopChassis = migrated.layer(.desktop) {
            migrateLegacyWorkflows(
                sources: legacyWorkflowLayerIDs,
                destinations: versionFiveDestinations,
                desktopChassis: desktopChassis,
                baseline: LegacyVersionFiveConfiguration.layer,
                in: &migrated
            )
            appendDefaultLayer(.cursor, desktopChassis: desktopChassis, to: &migrated)
            appendDefaultLayer(.meetingControls, desktopChassis: desktopChassis, to: &migrated)
        }
        migrated.schemaVersion = 7
        return migrated
    }

    static func migrateVersionSix(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        if let desktopChassis = migrated.layer(.desktop) {
            migrateLegacyWorkflows(
                sources: legacyWorkflowLayerIDs,
                destinations: versionSixDestinations,
                desktopChassis: desktopChassis,
                baseline: { id in
                    LegacyVersionSixConfiguration.layer(
                        id,
                        desktopChassis: desktopChassis
                    )
                },
                in: &migrated
            )
        }
        let desktopChassis = migrated.layer(.desktop)
        appendDefaultLayer(.cursor, desktopChassis: desktopChassis, to: &migrated)
        appendDefaultLayer(.meetingControls, desktopChassis: desktopChassis, to: &migrated)
        migrated.layers = migrated.layers.enumerated().sorted { left, right in
            let leftPosition = left.element.id.displayPosition
            let rightPosition = right.element.id.displayPosition
            return leftPosition == rightPosition
                ? left.offset < right.offset
                : leftPosition < rightPosition
        }.map(\.element)
        migrated.schemaVersion = 7
        return migrated
    }

    static func migrateVersionSeven(
        _ configuration: MicroConfiguration
    ) -> MicroConfiguration {
        var migrated = configuration
        let desktopChassis = migrated.layer(.desktop)
        upgradeVersionSevenPresetLayers(desktopChassis: desktopChassis, in: &migrated)
        appendDefaultLayer(.windowManagement, desktopChassis: desktopChassis, to: &migrated)
        appendDefaultLayer(.snippetCommands, desktopChassis: desktopChassis, to: &migrated)
        migrated.layers.sort { $0.id.displayPosition < $1.id.displayPosition }
        migrated.schemaVersion = MicroConfiguration.currentSchemaVersion
        return migrated
    }

    private static func upgradeVersionSevenPresetLayers(
        desktopChassis: LayerConfiguration?,
        in configuration: inout MicroConfiguration
    ) {
        guard let desktopChassis else { return }
        for id in LayerIndex.all {
            guard let preset = finalDefaultLayer(id, desktopChassis: desktopChassis) else { continue }
            upgradeMatchingShortcutNames(from: preset, on: id, in: &configuration)
        }
    }

    private static func upgradeMatchingShortcutNames(
        from preset: LayerConfiguration,
        on layerID: LayerIndex,
        in configuration: inout MicroConfiguration
    ) {
        for control in presetAgentControls {
            guard
                case .keyboardShortcut(let existing) = configuration.layer(layerID)?.action(for: control),
                existing.displayName == nil,
                case .keyboardShortcut(let named) = preset.action(for: control),
                existing == named.renamed(to: nil)
            else {
                continue
            }
            configuration.assign(action: .keyboardShortcut(named), to: control, on: layerID)
        }
    }

    private static func appendDefaultLayer(
        _ id: LayerIndex,
        desktopChassis: LayerConfiguration?,
        to configuration: inout MicroConfiguration
    ) {
        guard configuration.layer(id) == nil,
            let desktopChassis,
            let layer = finalDefaultLayer(id, desktopChassis: desktopChassis)
        else {
            return
        }
        configuration.layers.append(layer)
    }

    static func finalDefaultLayer(
        _ id: LayerIndex,
        desktopChassis: LayerConfiguration
    ) -> LayerConfiguration? {
        guard let presetID = MicroLayerPresetCatalog.defaultPresetID(for: id) else {
            return nil
        }
        return MicroLayerPresetCatalog.preset(for: presetID).layer(
            for: id,
            desktopChassis: desktopChassis
        )
    }

    static let legacyWorkflowLayerIDs: [LayerIndex] = [
        .codex, .agents, .windows, .meetings, .snippets,
    ]

    private static let presetAgentControls: [ControlID] = [
        .agent0, .agent1, .agent2, .agent3, .agent4, .agent5,
    ]

    static let versionFiveDestinations: [LayerIndex: LayerIndex] = [
        .codex: .codexCLI,
        .agents: .agentFocus,
        .windows: .windowManagement,
        .meetings: .meetingControls,
        .snippets: .snippetCommands,
    ]

    static let versionSixDestinations: [LayerIndex: LayerIndex] = [
        .codex: .codexCLI,
        .agents: .claudeCodeCLI,
        .windows: .codexApp,
        .meetings: .claudeApp,
        .snippets: .cursor,
    ]
}
