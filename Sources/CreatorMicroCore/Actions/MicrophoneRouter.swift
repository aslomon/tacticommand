public enum MicrophoneSwitch: String, Codable, CaseIterable, Hashable, Sendable {
    case left
    case right
}

public enum ButtonPhase: String, Codable, Hashable, Sendable {
    case pressed
    case released
}

public struct MicrophoneInput: Codable, Equatable, Sendable {
    public let switchID: MicrophoneSwitch
    public let phase: ButtonPhase

    public init(switchID: MicrophoneSwitch, phase: ButtonPhase) {
        self.switchID = switchID
        self.phase = phase
    }
}

public struct RoutedCreatorAction: Codable, Equatable, Sendable {
    public let action: CreatorAction
    public let phase: ButtonPhase

    public init(action: CreatorAction, phase: ButtonPhase) {
        self.action = action
        self.phase = phase
    }
}

public enum MicrophoneLayout: String, Codable, Equatable, Sendable {
    case linked
    case separate
}

public struct MicrophoneBindings: Codable, Equatable, Sendable {
    public let left: CreatorAction
    public let right: CreatorAction

    public init(left: CreatorAction, right: CreatorAction) {
        self.left = left
        self.right = right
    }

    public static func standard(dictation: DictationBinding) -> Self {
        Self(left: .dictation(dictation), right: .approval)
    }

    public func action(for switchID: MicrophoneSwitch) -> CreatorAction {
        switch switchID {
        case .left: left
        case .right: right
        }
    }
}

public struct MicrophoneRouter: Sendable {
    public let layout: MicrophoneLayout
    private var pressedSwitches: Set<MicrophoneSwitch> = []
    private var activeSeparateActions: [MicrophoneSwitch: CreatorAction] = [:]
    private var activeLinkedAction: CreatorAction?

    public init(layout: MicrophoneLayout) {
        self.layout = layout
    }

    public mutating func process(
        _ input: MicrophoneInput,
        bindings: MicrophoneBindings
    ) -> [RoutedCreatorAction] {
        switch input.phase {
        case .pressed:
            return handlePress(of: input.switchID, bindings: bindings)
        case .released:
            return handleRelease(of: input.switchID)
        }
    }

    public mutating func reset() -> [RoutedCreatorAction] {
        guard !pressedSwitches.isEmpty else { return [] }
        let releases = resetEvents()
        pressedSwitches.removeAll()
        activeSeparateActions.removeAll()
        activeLinkedAction = nil
        return releases
    }

    private mutating func handlePress(
        of switchID: MicrophoneSwitch,
        bindings: MicrophoneBindings
    ) -> [RoutedCreatorAction] {
        guard pressedSwitches.insert(switchID).inserted else { return [] }
        switch layout {
        case .linked:
            guard pressedSwitches.count == 1 else { return [] }
            let action = bindings.left
            activeLinkedAction = action
            return routed(action, phase: .pressed)
        case .separate:
            let action = bindings.action(for: switchID)
            activeSeparateActions[switchID] = action
            return routed(action, phase: .pressed)
        }
    }

    private mutating func handleRelease(
        of switchID: MicrophoneSwitch
    ) -> [RoutedCreatorAction] {
        guard pressedSwitches.remove(switchID) != nil else { return [] }
        switch layout {
        case .linked:
            guard pressedSwitches.isEmpty else { return [] }
            guard let action = activeLinkedAction else { return [] }
            activeLinkedAction = nil
            return routed(action, phase: .released)
        case .separate:
            guard let action = activeSeparateActions.removeValue(forKey: switchID) else {
                return []
            }
            return routed(action, phase: .released)
        }
    }

    private func resetEvents() -> [RoutedCreatorAction] {
        switch layout {
        case .linked:
            guard let action = activeLinkedAction else { return [] }
            return routed(action, phase: .released)
        case .separate:
            return MicrophoneSwitch.allCases.flatMap { switchID -> [RoutedCreatorAction] in
                guard let action = activeSeparateActions[switchID] else { return [] }
                return routed(action, phase: .released)
            }
        }
    }

    private func routed(
        _ action: CreatorAction,
        phase: ButtonPhase
    ) -> [RoutedCreatorAction] {
        guard action != .none else { return [] }
        return [RoutedCreatorAction(action: action, phase: phase)]
    }
}
