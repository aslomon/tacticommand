import Foundation

public struct LightingFeedbackTracker: Sendable {
    public struct Feedback: Equatable, Sendable {
        public let pressLift: Double
        public let isFailing: Bool
    }

    private struct Press: Sendable {
        let started: ContinuousClock.Instant
        var released: ContinuousClock.Instant?
        var releaseLift: Double = 0
    }

    private var presses: [ControlID: Press] = [:]
    private var failures: [ControlID: ContinuousClock.Instant] = [:]

    public init() {}

    public mutating func press(_ control: ControlID, at instant: ContinuousClock.Instant) {
        guard presses[control]?.released != nil || presses[control] == nil else { return }
        presses[control] = Press(started: instant)
    }

    public mutating func release(_ control: ControlID, at instant: ContinuousClock.Instant) {
        guard var press = presses[control], press.released == nil else { return }
        press.releaseLift = lift(press, at: instant)
        press.released = instant
        presses[control] = press
    }

    public mutating func failure(_ control: ControlID, at instant: ContinuousClock.Instant) {
        failures[control] = instant.advanced(by: .seconds(1))
    }

    public func feedback(for control: ControlID, at instant: ContinuousClock.Instant) -> Feedback {
        Feedback(
            pressLift: presses[control].map { lift($0, at: instant) } ?? 0,
            isFailing: failures[control].map { instant < $0 } ?? false)
    }

    public func tracks(_ control: ControlID) -> Bool { presses[control] != nil }

    public func nextDeadline(at instant: ContinuousClock.Instant) -> ContinuousClock.Instant? {
        let transitions = presses.values.map {
            $0.released?.advanced(by: .milliseconds(160))
                ?? $0.started.advanced(by: .milliseconds(90))
        }
        return (transitions + Array(failures.values)).filter { $0 > instant }.min()
    }

    public func hasActiveFeedback(at instant: ContinuousClock.Instant) -> Bool {
        presses.values.contains { lift($0, at: instant) > 0 }
            || failures.values.contains { $0 > instant }
    }

    public mutating func prune(at instant: ContinuousClock.Instant) {
        presses = presses.filter { $0.value.released == nil || lift($0.value, at: instant) > 0 }
        failures = failures.filter { $0.value > instant }
    }

    public mutating func reset() {
        presses.removeAll()
        failures.removeAll()
    }

    private func lift(_ press: Press, at instant: ContinuousClock.Instant) -> Double {
        if let released = press.released {
            return press.releaseLift * (1 - fraction(released.duration(to: instant), milliseconds: 160))
        }
        return fraction(press.started.duration(to: instant), milliseconds: 90)
    }

    private func fraction(_ duration: Duration, milliseconds: Double) -> Double {
        let parts = duration.components
        let elapsed = Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
        return min(1, max(0, elapsed / milliseconds))
    }
}
