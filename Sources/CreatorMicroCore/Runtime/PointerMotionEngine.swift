import Foundation

public struct PointerMotionDelta: Equatable, Sendable {
    public static let stationary = PointerMotionDelta(horizontal: 0, vertical: 0)

    public let horizontal: Int
    public let vertical: Int

    public init(horizontal: Int, vertical: Int) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public var isStationary: Bool {
        horizontal == 0 && vertical == 0
    }
}

public struct PointerMotionEngine: Sendable {
    private let staleAfter: TimeInterval
    private let maximumStep: TimeInterval
    private var configuration: JoystickConfiguration
    private var sample = RadialInputEvent(angle: 0, distance: 0)
    private var sampledAt: TimeInterval?
    private var lastTick: TimeInterval?
    private var horizontalRemainder = 0.0
    private var verticalRemainder = 0.0

    public init(
        configuration: JoystickConfiguration,
        staleAfter: TimeInterval = 4,
        maximumStep: TimeInterval = 0.05
    ) {
        self.configuration = configuration
        self.staleAfter = staleAfter
        self.maximumStep = maximumStep
    }

    public mutating func update(
        _ sample: RadialInputEvent,
        at time: TimeInterval
    ) {
        self.sample = sample
        sampledAt = time
        if sample.distance <= configuration.deadZone {
            clearRemainders()
        }
    }

    public mutating func update(configuration: JoystickConfiguration) {
        self.configuration = configuration
    }

    public mutating func tick(at time: TimeInterval) -> PointerMotionDelta {
        guard let previousTick = lastTick else {
            lastTick = time
            return .stationary
        }
        lastTick = time
        guard isMoving(at: time) else {
            clearRemainders()
            return .stationary
        }
        let elapsed = min(max(time - previousTick, 0), maximumStep)
        return integrate(elapsed: elapsed)
    }

    public mutating func stop() {
        sample = RadialInputEvent(angle: 0, distance: 0)
        sampledAt = nil
        lastTick = nil
        clearRemainders()
    }

    public func isMoving(at time: TimeInterval) -> Bool {
        isSampleFresh(at: time) && sample.distance > configuration.deadZone
    }

    private func isSampleFresh(at time: TimeInterval) -> Bool {
        guard let sampledAt else { return false }
        return time - sampledAt <= staleAfter
    }

    private mutating func integrate(elapsed: TimeInterval) -> PointerMotionDelta {
        let theta = 2 * Double.pi * sample.angle
        let speed = curvedSpeed(distance: sample.distance)
        horizontalRemainder += cos(theta) * speed * elapsed
        verticalRemainder += sin(theta) * speed * elapsed
        let horizontal = Int(horizontalRemainder.rounded(.towardZero))
        let vertical = Int(verticalRemainder.rounded(.towardZero))
        horizontalRemainder -= Double(horizontal)
        verticalRemainder -= Double(vertical)
        return PointerMotionDelta(horizontal: horizontal, vertical: vertical)
    }

    private func curvedSpeed(distance: Double) -> Double {
        let usableRange = 1 - configuration.deadZone
        guard usableRange > 0 else { return configuration.maximumSpeed }
        let reach = min(1, (distance - configuration.deadZone) / usableRange)
        return configuration.maximumSpeed * pow(reach, 3)
    }

    private mutating func clearRemainders() {
        horizontalRemainder = 0
        verticalRemainder = 0
    }
}
