extension MicroConfigurationMigrator {
    static func migrateLegacyWorkflows(
        sources: [LayerIndex],
        destinations: [LayerIndex: LayerIndex],
        desktopChassis: LayerConfiguration,
        baseline: (LayerIndex) -> LayerConfiguration,
        in configuration: inout MicroConfiguration
    ) {
        let customizedLayers = customizedLegacyLayers(
            sources: sources,
            baseline: baseline,
            in: configuration
        )
        installDefaultWorkflowLayers(
            sources: sources,
            desktopChassis: desktopChassis,
            in: &configuration
        )
        installCustomizedLayers(
            customizedLayers,
            destinations: destinations,
            in: &configuration
        )
        remapLayerReferences(using: destinations, in: &configuration)
    }

    private static func customizedLegacyLayers(
        sources: [LayerIndex],
        baseline: (LayerIndex) -> LayerConfiguration,
        in configuration: MicroConfiguration
    ) -> [LayerIndex: LayerConfiguration] {
        var result: [LayerIndex: LayerConfiguration] = [:]
        for source in sources {
            guard let layer = configuration.layer(source), layer != baseline(source) else {
                continue
            }
            result[source] = layer
        }
        return result
    }

    private static func installDefaultWorkflowLayers(
        sources: [LayerIndex],
        desktopChassis: LayerConfiguration,
        in configuration: inout MicroConfiguration
    ) {
        for source in sources {
            guard let layer = finalDefaultLayer(source, desktopChassis: desktopChassis) else {
                continue
            }
            install(layer, in: &configuration)
        }
    }

    private static func installCustomizedLayers(
        _ layers: [LayerIndex: LayerConfiguration],
        destinations: [LayerIndex: LayerIndex],
        in configuration: inout MicroConfiguration
    ) {
        for (source, layer) in layers {
            guard let destination = destinations[source] else { continue }
            install(reidentify(layer, as: destination), in: &configuration)
        }
    }

    private static func install(
        _ layer: LayerConfiguration,
        in configuration: inout MicroConfiguration
    ) {
        if let index = configuration.layers.firstIndex(where: { $0.id == layer.id }) {
            configuration.layers[index] = layer
        } else {
            configuration.layers.append(layer)
        }
    }

    private static func reidentify(
        _ layer: LayerConfiguration,
        as destination: LayerIndex
    ) -> LayerConfiguration {
        LayerConfiguration(
            id: destination,
            name: layer.name,
            bindings: layer.bindings,
            joystick: layer.joystick
        )
    }

    private static func remapLayerReferences(
        using destinations: [LayerIndex: LayerIndex],
        in configuration: inout MicroConfiguration
    ) {
        for ruleIndex in configuration.applicationLayerRules.indices {
            let source = configuration.applicationLayerRules[ruleIndex].layer
            configuration.applicationLayerRules[ruleIndex].layer = destinations[source] ?? source
        }
        for layerIndex in configuration.layers.indices {
            configuration.layers[layerIndex].bindings = configuration.layers[layerIndex].bindings.mapValues {
                remapLayerReferences(in: $0, using: destinations)
            }
        }
    }

    private static func remapLayerReferences(
        in action: CreatorAction,
        using destinations: [LayerIndex: LayerIndex]
    ) -> CreatorAction {
        switch action {
        case .layer(.select(let source)):
            return .layer(.select(destinations[source] ?? source))
        case .shortOrLongPress(let shortPress, let longPress):
            return .shortOrLongPress(
                shortPress: remapLayerReferences(in: shortPress, using: destinations),
                longPress: remapLayerReferences(in: longPress, using: destinations)
            )
        case .actionSequence(let actions):
            return .actionSequence(
                actions.map { remapLayerReferences(in: $0, using: destinations) }
            )
        default:
            return action
        }
    }
}
