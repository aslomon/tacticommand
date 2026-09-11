import Foundation

public enum JoystickArrowKey: String, CaseIterable, Codable, Hashable, Sendable {
    case left
    case right
    case up
    case down
}

public struct JoystickArrowKeyTransition: Equatable, Sendable {
    public let key: JoystickArrowKey
    public let phase: ButtonPhase

    public init(key: JoystickArrowKey, phase: ButtonPhase) {
        self.key = key
        self.phase = phase
    }
}

public struct JoystickArrowKeyStateMachine: Sendable {
    public private(set) var activeKey: JoystickArrowKey?
    public private(set) var isSuspendedUntilCentered = false

    private let deadZone: Double
    private let staleAfter: TimeInterval
    private let axisHysteresis: Double
    private var sampledAt: TimeInterval?

    public init(
        deadZone: Double,
        staleAfter: TimeInterval = 4,
        axisHysteresis: Double = 0.12
    ) {
        self.deadZone = Self.normalizedDeadZone(deadZone)
        self.staleAfter = Self.normalizedTimeout(staleAfter)
        self.axisHysteresis = min(max(axisHysteresis, 0), 1)
    }

    public mutating func update(
        _ sample: RadialInputEvent,
        at time: TimeInterval
    ) -> [JoystickArrowKeyTransition] {
        guard time.isFinite else { return reset() }
        if isSuspendedUntilCentered {
            guard isCentered(sample) else { return [] }
            isSuspendedUntilCentered = false
            sampledAt = nil
            return []
        }
        sampledAt = time
        return transition(to: direction(for: sample))
    }

    public mutating func resetIfStale(
        at time: TimeInterval
    ) -> [JoystickArrowKeyTransition] {
        guard time.isFinite else { return reset() }
        guard let sampledAt, time - sampledAt > staleAfter else { return [] }
        return suspendUntilCentered()
    }

    public mutating func reset() -> [JoystickArrowKeyTransition] {
        sampledAt = nil
        return transition(to: nil)
    }

    public mutating func suspendUntilCentered() -> [JoystickArrowKeyTransition] {
        let transitions = reset()
        isSuspendedUntilCentered = true
        return transitions
    }

    private func direction(for sample: RadialInputEvent) -> JoystickArrowKey? {
        guard sample.angle.isFinite,
            sample.distance.isFinite,
            (0...1).contains(sample.angle),
            (0...1).contains(sample.distance),
            sample.distance > deadZone
        else {
            return nil
        }
        let radians = 2 * Double.pi * sample.angle
        let horizontal = cos(radians)
        let vertical = sin(radians)
        let candidate = cardinalDirection(horizontal: horizontal, vertical: vertical)
        guard let activeKey, isAxisChange(from: activeKey, to: candidate) else {
            return candidate
        }
        let currentStrength = strength(of: activeKey, horizontal: horizontal, vertical: vertical)
        let candidateStrength = strength(of: candidate, horizontal: horizontal, vertical: vertical)
        return candidateStrength > currentStrength + axisHysteresis ? candidate : activeKey
    }

    private func isCentered(_ sample: RadialInputEvent) -> Bool {
        sample.distance.isFinite && sample.distance <= deadZone
    }

    private func cardinalDirection(
        horizontal: Double,
        vertical: Double
    ) -> JoystickArrowKey {
        if abs(horizontal) >= abs(vertical) {
            return horizontal >= 0 ? .right : .left
        }
        return vertical >= 0 ? .down : .up
    }

    private func isAxisChange(
        from current: JoystickArrowKey,
        to candidate: JoystickArrowKey
    ) -> Bool {
        current.isHorizontal != candidate.isHorizontal
    }

    private func strength(
        of key: JoystickArrowKey,
        horizontal: Double,
        vertical: Double
    ) -> Double {
        key.isHorizontal ? abs(horizontal) : abs(vertical)
    }

    private mutating func transition(
        to nextKey: JoystickArrowKey?
    ) -> [JoystickArrowKeyTransition] {
        guard nextKey != activeKey else { return [] }
        var transitions: [JoystickArrowKeyTransition] = []
        if let activeKey {
            transitions.append(.init(key: activeKey, phase: .released))
        }
        if let nextKey {
            transitions.append(.init(key: nextKey, phase: .pressed))
        }
        activeKey = nextKey
        return transitions
    }

    private static func normalizedDeadZone(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, 0), 1)
    }

    private static func normalizedTimeout(_ value: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return 0 }
        return max(value, 0)
    }
}

extension JoystickArrowKey {
    fileprivate var isHorizontal: Bool {
        self == .left || self == .right
    }
}
