public struct ShortOrLongPressDeadline: Equatable, Hashable, Sendable {
    public let control: ControlID
    public let delayMilliseconds: Int
    fileprivate let generation: UInt64
}

public enum ShortOrLongPressEffect: Equatable, Sendable {
    case schedule(ShortOrLongPressDeadline)
    case emit(RoutedCreatorAction)
}

public struct ShortOrLongPressStateMachine: Sendable {
    public static let thresholdMilliseconds = 450

    private enum ActivePress: Sendable {
        case pending(
            shortPress: CreatorAction,
            longPress: CreatorAction,
            deadline: ShortOrLongPressDeadline
        )
        case longActive(CreatorAction)
    }

    private var activePresses: [ControlID: ActivePress] = [:]
    private var nextGeneration: UInt64 = 0

    public init() {}

    public mutating func begin(
        control: ControlID,
        shortPress: CreatorAction,
        longPress: CreatorAction
    ) -> [ShortOrLongPressEffect] {
        guard activePresses[control] == nil else { return [] }
        nextGeneration &+= 1
        let deadline = ShortOrLongPressDeadline(
            control: control,
            delayMilliseconds: Self.thresholdMilliseconds,
            generation: nextGeneration
        )
        activePresses[control] = .pending(
            shortPress: shortPress,
            longPress: longPress,
            deadline: deadline
        )
        return [.schedule(deadline)]
    }

    public mutating func thresholdReached(
        _ deadline: ShortOrLongPressDeadline
    ) -> [ShortOrLongPressEffect] {
        guard case .pending(_, let longPress, let activeDeadline) = activePresses[deadline.control],
            activeDeadline == deadline
        else {
            return []
        }
        activePresses[deadline.control] = .longActive(longPress)
        return [.emit(event(longPress, phase: .pressed))]
    }

    public mutating func release(
        control: ControlID
    ) -> [ShortOrLongPressEffect] {
        guard let activePress = activePresses.removeValue(forKey: control) else {
            return []
        }
        switch activePress {
        case .pending(let shortPress, _, _):
            return [
                .emit(event(shortPress, phase: .pressed)),
                .emit(event(shortPress, phase: .released)),
            ]
        case .longActive(let longPress):
            return [.emit(event(longPress, phase: .released))]
        }
    }

    public mutating func reset() -> [ShortOrLongPressEffect] {
        let effects: [ShortOrLongPressEffect] = ControlID.allCases.compactMap { control in
            guard case .longActive(let action) = activePresses[control] else {
                return nil
            }
            return ShortOrLongPressEffect.emit(event(action, phase: .released))
        }
        activePresses.removeAll()
        return effects
    }

    public func isTracking(_ control: ControlID) -> Bool {
        activePresses[control] != nil
    }

    private func event(
        _ action: CreatorAction,
        phase: ButtonPhase
    ) -> RoutedCreatorAction {
        RoutedCreatorAction(action: action, phase: phase)
    }
}
