import CreatorMicroCore
import Foundation

actor LocalAutomationRequestProcessor {
    private let handlers: LocalAutomationHandlers
    private var isRunning = false

    init(handlers: LocalAutomationHandlers) {
        self.handlers = handlers
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func response(
        for frame: LocalAutomationFrame
    ) async -> LocalAutomationResponse? {
        guard isRunning else { return nil }
        switch frame {
        case .frameTooLarge:
            return oversizedFrameResponse()
        case .line(let line):
            return await response(for: line)
        }
    }

    private func response(for line: Data) async -> LocalAutomationResponse? {
        guard isRunning else { return nil }
        switch LocalAutomationCodec().decodeRequest(line) {
        case .failure(let failure):
            return .failure(id: failure.requestID, error: failure.error)
        case .success(let request):
            return await execute(request)
        }
    }

    private func execute(
        _ request: LocalAutomationRequest
    ) async -> LocalAutomationResponse? {
        guard isRunning else { return nil }
        switch request.command {
        case .status:
            return await status(requestID: request.id)
        case .listLayers:
            return await layers(requestID: request.id)
        case .setLayer(let layer):
            return await setLayer(layer, requestID: request.id)
        case .triggerBinding(let control, let layer):
            return await trigger(control, layer: layer, requestID: request.id)
        }
    }

    private func status(requestID: String) async -> LocalAutomationResponse? {
        let status = await handlers.status()
        guard isRunning else { return nil }
        return .success(id: requestID, result: .status(status))
    }

    private func layers(requestID: String) async -> LocalAutomationResponse? {
        let layers = await handlers.listLayers()
        guard isRunning else { return nil }
        return .success(id: requestID, result: .layers(layers))
    }

    private func setLayer(
        _ layer: LayerIndex,
        requestID: String
    ) async -> LocalAutomationResponse? {
        guard await configurationIsReady() else {
            return isRunning ? configurationLoading(id: requestID) : nil
        }
        let result = await handlers.setLayer(layer)
        guard isRunning else { return nil }
        switch result {
        case .success:
            return .success(id: requestID, result: .layerSelected(layer))
        case .failure(let failure):
            return executionFailure(id: requestID, message: failure.message)
        }
    }

    private func trigger(
        _ control: ControlID,
        layer: LayerIndex,
        requestID: String
    ) async -> LocalAutomationResponse? {
        guard await configurationIsReady() else {
            return isRunning ? configurationLoading(id: requestID) : nil
        }
        let action = await handlers.resolveBinding(control, layer)
        guard isRunning else { return nil }
        switch LocalAutomationBindingPolicy.events(for: action) {
        case .failure(let error):
            return .failure(id: requestID, error: error)
        case .success(let events):
            return await perform(
                events,
                action: action,
                control: control,
                layer: layer,
                requestID: requestID
            )
        }
    }

    private func perform(
        _ events: [RoutedCreatorAction],
        action: CreatorAction,
        control: ControlID,
        layer: LayerIndex,
        requestID: String
    ) async -> LocalAutomationResponse? {
        for event in events {
            guard isRunning else { return nil }
            let result = await handlers.perform(event)
            guard isRunning else { return nil }
            if case .failure(let failure) = result {
                return executionFailure(id: requestID, message: failure.message)
            }
        }
        let receipt = LocalAutomationTriggerReceipt(
            control: control,
            layer: layer,
            action: LocalAutomationBindingPolicy.kind(of: action)
        )
        return .success(id: requestID, result: .bindingTriggered(receipt))
    }

    private func configurationIsReady() async -> Bool {
        guard isRunning else { return false }
        let status = await handlers.status()
        return isRunning && status.isReady
    }

    private func oversizedFrameResponse() -> LocalAutomationResponse {
        .failure(
            id: nil,
            error: LocalAutomationError(
                code: .frameTooLarge,
                message: "The request exceeds the size limit."
            )
        )
    }

    private func configurationLoading(id: String) -> LocalAutomationResponse {
        executionFailure(
            id: id,
            message: "TactiCommand is still loading its configuration."
        )
    }

    private func executionFailure(
        id: String,
        message: String
    ) -> LocalAutomationResponse {
        .failure(
            id: id,
            error: LocalAutomationError(code: .executionFailed, message: message)
        )
    }
}
