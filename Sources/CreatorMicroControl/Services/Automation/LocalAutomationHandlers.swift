import CreatorMicroCore
import Foundation

public struct LocalAutomationHandlerFailure: Error, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        let singleLine = message.replacingOccurrences(of: "\n", with: " ")
        self.message = String(singleLine.prefix(256))
    }
}

public struct LocalAutomationHandlers: Sendable {
    public typealias StatusHandler = @Sendable () async -> LocalAutomationStatus
    public typealias LayersHandler = @Sendable () async -> [LocalAutomationLayer]
    public typealias LayerHandler =
        @Sendable (
            LayerIndex
        ) async -> Result<Void, LocalAutomationHandlerFailure>
    public typealias BindingResolver =
        @Sendable (
            ControlID,
            LayerIndex
        ) async -> CreatorAction
    public typealias ActionHandler =
        @Sendable (
            RoutedCreatorAction
        ) async -> Result<Void, LocalAutomationHandlerFailure>

    let status: StatusHandler
    let listLayers: LayersHandler
    let setLayer: LayerHandler
    let resolveBinding: BindingResolver
    let perform: ActionHandler

    public init(
        status: @escaping StatusHandler,
        listLayers: @escaping LayersHandler,
        setLayer: @escaping LayerHandler,
        resolveBinding: @escaping BindingResolver,
        perform: @escaping ActionHandler
    ) {
        self.status = status
        self.listLayers = listLayers
        self.setLayer = setLayer
        self.resolveBinding = resolveBinding
        self.perform = perform
    }

    public func setLayerIfReady(
        _ layer: LayerIndex
    ) async -> Result<Void, LocalAutomationHandlerFailure> {
        guard await status().isReady else { return .failure(.configurationLoading) }
        return await setLayer(layer)
    }

    public func resolveBindingIfReady(
        _ control: ControlID,
        layer: LayerIndex
    ) async -> Result<CreatorAction, LocalAutomationHandlerFailure> {
        guard await status().isReady else { return .failure(.configurationLoading) }
        return .success(await resolveBinding(control, layer))
    }
}

extension LocalAutomationHandlerFailure {
    fileprivate static var configurationLoading: LocalAutomationHandlerFailure {
        LocalAutomationHandlerFailure(
            message: "TactiCommand is still loading its configuration."
        )
    }
}
