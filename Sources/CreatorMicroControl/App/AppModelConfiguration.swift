import CreatorMicroCore

extension AppModel {
    var installedApplicationChoices: [InstalledApplicationChoice] {
        providers.compactMap { provider in
            guard let identifier = provider.applicationBundleIdentifier else { return nil }
            return InstalledApplicationChoice(
                bundleIdentifier: identifier,
                name: provider.displayName
            )
        }
    }

    func chooseProvider(
        _ provider: DictationProviderDefinition,
        for control: ControlID = .action10
    ) {
        let currentAction = selectedLayer.action(for: control)
        let currentBehavior = DictationActionEditor.binding(in: currentAction)?.behavior
        let behavior =
            currentBehavior.flatMap { behavior in
                provider.supportedBehaviors.contains(behavior) ? behavior : nil
            } ?? provider.defaultBehavior
        let binding = DictationBinding(
            providerID: provider.id,
            behavior: behavior,
            shortcut: provider.defaultShortcut
        )
        assign(
            DictationActionEditor.replacingDictation(in: currentAction, with: binding),
            to: control
        )
    }

    func setDictationBehavior(
        _ behavior: DictationBehavior,
        for control: ControlID = .action10
    ) {
        guard let current = dictationBinding(for: control),
            let provider = provider(for: current.providerID),
            provider.supportedBehaviors.contains(behavior)
        else {
            return
        }
        assign(.dictation(current.replacing(behavior: behavior)), to: control)
    }

    func setShortcut(_ shortcut: KeyShortcut?, for control: ControlID) {
        guard let current = dictationBinding(for: control) else { return }
        assign(.dictation(current.replacing(shortcut: shortcut)), to: control)
    }

    func dictationBinding(for control: ControlID) -> DictationBinding? {
        DictationActionEditor.binding(in: selectedLayer.action(for: control))
    }

    func provider(for id: DictationProviderID) -> DictationProviderDefinition? {
        providers.first { $0.id == id }
    }

    func applicationRule(for layer: LayerIndex) -> String? {
        configuration.applicationLayerRules.first { $0.layer == layer }?.bundleIdentifier
    }

    func setApplicationRule(bundleIdentifier: String?, for layer: LayerIndex) {
        guard canMutateConfiguration else { return }
        configuration.applicationLayerRules.removeAll { rule in
            rule.layer == layer || rule.bundleIdentifier == bundleIdentifier
        }
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            configuration.applicationLayerRules.append(
                ApplicationLayerRule(bundleIdentifier: bundleIdentifier, layer: layer)
            )
        }
        reevaluateApplicationLayerRule()
        saveConfiguration()
    }

    func applyPreset(
        _ preset: MicroLayerPresetID,
        to layer: LayerIndex? = nil
    ) {
        guard canMutateConfiguration else { return }
        configuration.applyPreset(preset, to: layer ?? activeLayer)
        saveConfiguration()
    }

    func renameLayer(_ proposedName: String, layer: LayerIndex? = nil) {
        guard canMutateConfiguration else { return }
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.utf8.count <= 128 else { return }
        let target = layer ?? activeLayer
        guard let index = configuration.layers.firstIndex(where: { $0.id == target }) else {
            return
        }
        configuration.layers[index].name = name
        saveConfiguration()
    }

    func refreshProviders() async {
        switch await providerRegistry.providers() {
        case .success(let discovered):
            providers = discovered
        case .failure(let error):
            lastError = "Application discovery failed: \(error)"
        }
    }

    func loadConfiguration() async {
        switch await configurationStore.load() {
        case .success(let loaded):
            configuration = loaded
            runtimeRouter = MicroRuntimeRouter(microphoneLayout: loaded.microphoneLayout)
        case .failure(let error):
            configuration = .default
            runtimeRouter = MicroRuntimeRouter(microphoneLayout: configuration.microphoneLayout)
            lastError = error.localizedDescription
        }
        isReady = true
    }

    func saveConfiguration() {
        guard canMutateConfiguration else { return }
        resetLightingBoundary()
        releaseActiveMicrophoneActions()
        configureRuntimeRouter()
        refreshLightingAfterLayerChange()
        configurationGeneration &+= 1
        let snapshot = configuration
        let generation = configurationGeneration
        let store = configurationStore
        let precedingSave = configurationSaveTask
        configurationSaveTask = Task { [self] in
            await precedingSave?.value
            guard !Task.isCancelled else { return }
            guard generation == configurationGeneration else { return }
            let result = await store.save(snapshot, generation: generation)
            recordConfigurationSave(result, generation: generation)
        }
    }

    func flushConfiguration() async {
        guard configurationGeneration > 0 else { return }
        while true {
            let pendingGeneration = configurationGeneration
            let pendingTask = configurationSaveTask
            await pendingTask?.value
            guard pendingGeneration == configurationGeneration else { continue }

            configurationGeneration &+= 1
            let flushGeneration = configurationGeneration
            let snapshot = configuration
            let result = await configurationStore.save(
                snapshot,
                generation: flushGeneration
            )
            recordConfigurationSave(result, generation: flushGeneration)
            guard flushGeneration == configurationGeneration else { continue }
            return
        }
    }

    private func recordConfigurationSave(
        _ result: Result<Void, ConfigurationStoreError>,
        generation: UInt64
    ) {
        guard generation == configurationGeneration else { return }
        if case .failure(let error) = result {
            lastError = error.localizedDescription
        }
    }

    func releaseActiveMicrophoneActions() {
        let releases = resetActiveRoutedActions()
        Task { [weak self] in
            guard let self else { return }
            for release in releases {
                await execute(release)
            }
        }
    }
}

enum DictationActionEditor {
    static func binding(in action: CreatorAction) -> DictationBinding? {
        switch action {
        case .dictation(let binding):
            binding
        case .shortOrLongPress(let shortPress, let longPress):
            directBinding(in: shortPress) ?? directBinding(in: longPress)
        default:
            nil
        }
    }

    static func replacingDictation(
        in action: CreatorAction,
        with binding: DictationBinding
    ) -> CreatorAction {
        guard case .shortOrLongPress(let shortPress, let longPress) = action else {
            return .dictation(binding)
        }
        if directBinding(in: shortPress) != nil {
            return .shortOrLongPress(
                shortPress: .dictation(binding),
                longPress: longPress
            )
        }
        if directBinding(in: longPress) != nil {
            return .shortOrLongPress(
                shortPress: shortPress,
                longPress: .dictation(binding)
            )
        }
        return .dictation(binding)
    }

    private static func directBinding(in action: CreatorAction) -> DictationBinding? {
        guard case .dictation(let binding) = action else { return nil }
        return binding
    }
}

struct InstalledApplicationChoice: Identifiable, Equatable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }
}

extension DictationBinding {
    fileprivate func replacing(behavior: DictationBehavior) -> DictationBinding {
        DictationBinding(
            providerID: providerID,
            behavior: behavior,
            shortcut: shortcut
        )
    }

    fileprivate func replacing(shortcut: KeyShortcut?) -> DictationBinding {
        DictationBinding(
            providerID: providerID,
            behavior: behavior,
            shortcut: shortcut
        )
    }
}
