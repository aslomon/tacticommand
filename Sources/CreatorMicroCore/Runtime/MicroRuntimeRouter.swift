public struct MicroRuntimeRouter: Sendable {
    public private(set) var microphoneLayout: MicrophoneLayout
    private var microphoneRouter: MicrophoneRouter
    private var activeRegularActions: [ControlID: CreatorAction] = [:]

    public init(microphoneLayout: MicrophoneLayout) {
        self.microphoneLayout = microphoneLayout
        microphoneRouter = MicrophoneRouter(layout: microphoneLayout)
    }

    public mutating func route(
        _ input: MicroInputEvent,
        on layer: LayerConfiguration
    ) -> [RoutedCreatorAction] {
        if let microphoneInput = microphoneInput(from: input) {
            return microphoneRouter.process(
                microphoneInput,
                bindings: MicrophoneBindings(
                    left: layer.action(for: .action10),
                    right: layer.action(for: .action11)
                )
            )
        }
        return routeRegular(input, on: layer)
    }

    public mutating func reset() -> [RoutedCreatorAction] {
        let microphoneReleases = microphoneRouter.reset()
        let regularReleases = ControlID.allCases.compactMap { control -> RoutedCreatorAction? in
            guard let action = activeRegularActions[control], action != .none else {
                return nil
            }
            return RoutedCreatorAction(action: action, phase: .released)
        }
        activeRegularActions.removeAll()
        return microphoneReleases + regularReleases
    }

    private mutating func routeRegular(
        _ input: MicroInputEvent,
        on layer: LayerConfiguration
    ) -> [RoutedCreatorAction] {
        switch input.phase {
        case .pressed:
            guard activeRegularActions[input.control] == nil else { return [] }
            let action = layer.action(for: input.control)
            activeRegularActions[input.control] = action
            return routed(action, phase: .pressed)
        case .released:
            guard let action = activeRegularActions.removeValue(forKey: input.control) else {
                return []
            }
            return routed(action, phase: .released)
        case .pulse:
            return routed(layer.action(for: input.control), phase: .pressed)
        }
    }

    private func microphoneInput(from input: MicroInputEvent) -> MicrophoneInput? {
        let switchID: MicrophoneSwitch
        switch input.control {
        case .action10: switchID = .left
        case .action11: switchID = .right
        default: return nil
        }
        guard input.phase != .pulse else { return nil }
        return MicrophoneInput(
            switchID: switchID,
            phase: buttonPhase(from: input.phase)
        )
    }

    private func buttonPhase(from phase: MicroInputPhase) -> ButtonPhase {
        phase == .released ? .released : .pressed
    }

    private func routed(
        _ action: CreatorAction,
        phase: ButtonPhase
    ) -> [RoutedCreatorAction] {
        guard action != .none else { return [] }
        return [RoutedCreatorAction(action: action, phase: phase)]
    }
}
