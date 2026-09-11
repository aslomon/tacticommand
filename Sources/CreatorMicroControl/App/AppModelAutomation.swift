import CreatorMicroCore

extension AppModel {
    func startAutomationServer() {
        guard isReady else { return }
        guard automationServer == nil else { return }
        let server = LocalAutomationServer(handlers: makeAutomationHandlers())
        automationServer = server
        automationServerStartTask = Task { [weak self] in
            let result = await server.start()
            guard let self, !Task.isCancelled else { return }
            automationServerStartTask = nil
            switch result {
            case .success(let url):
                automationSocketPath = url.path
            case .failure(let failure):
                lastError = "Local automation could not start: \(failure)"
            }
        }
    }

    func makeAutomationHandlers() -> LocalAutomationHandlers {
        LocalAutomationHandlers(
            status: { [weak self] in await self?.localAutomationStatus() ?? .offline },
            listLayers: { [weak self] in await self?.localAutomationLayers() ?? [] },
            setLayer: { [weak self] layer in
                await self?.selectLayerForAutomation(layer) ?? .failure(.appUnavailable)
            },
            resolveBinding: { [weak self] control, layer in
                await self?.configuration.layer(layer)?.action(for: control) ?? .none
            },
            perform: { [weak self] event in
                await self?.executeRoutedAction(
                    event,
                    layerSource: .automation
                ) ?? .failure(.appUnavailable)
            }
        )
    }

    private func localAutomationStatus() -> LocalAutomationStatus {
        LocalAutomationStatus(
            activeLayer: activeLayer,
            isReady: isReady,
            connection: localAutomationConnection,
            device: deviceStatus,
            layerSource: layerSelection.source
        )
    }

    private func localAutomationLayers() -> [LocalAutomationLayer] {
        configuration.layers.map {
            LocalAutomationLayer(index: $0.id, name: $0.name)
        }
    }

    private func selectLayerForAutomation(
        _ layer: LayerIndex
    ) -> Result<Void, LocalAutomationHandlerFailure> {
        guard configuration.layer(layer) != nil else {
            return .failure(LocalAutomationHandlerFailure(message: "Layer is unavailable."))
        }
        select(layer: layer, source: .automation)
        return .success(())
    }

    private var localAutomationConnection: LocalAutomationConnection {
        switch connectionState {
        case .disconnected: .disconnected
        case .connecting: .connecting
        case .connected: .connected
        case .unavailable: .unavailable
        }
    }
}

extension LocalAutomationStatus {
    fileprivate static var offline: LocalAutomationStatus {
        LocalAutomationStatus(
            activeLayer: .desktop,
            isReady: false,
            connection: .disconnected
        )
    }
}

extension LocalAutomationHandlerFailure {
    fileprivate static var appUnavailable: LocalAutomationHandlerFailure {
        LocalAutomationHandlerFailure(message: "TactiCommand is unavailable.")
    }
}
