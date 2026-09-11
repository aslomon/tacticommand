import AppKit
import CreatorMicroCore
import Foundation

@MainActor
protocol JoystickArrowKeyEventSending: Sendable {
    func send(
        _ shortcut: KeyShortcut,
        phase: ButtonPhase
    ) -> Result<Void, SystemEventFailure>

    func releaseForCleanup(
        _ shortcut: KeyShortcut
    ) -> Result<Void, SystemEventFailure>

    func repeatKey(
        _ shortcut: KeyShortcut
    ) -> Result<Void, SystemEventFailure>
}

extension SystemEventSynthesizer: JoystickArrowKeyEventSending {}

@MainActor
final class JoystickArrowKeyController {
    var onFailure: ((SystemEventFailure) -> Void)?

    private let events: any JoystickArrowKeyEventSending
    private let staleAfter: TimeInterval
    private let repeatDelay: Duration
    private let repeatInterval: Duration
    private var machine: JoystickArrowKeyStateMachine
    private var configuredDeadZone: Double
    private var staleTask: Task<Void, Never>?
    private var staleGeneration: UInt64 = 0
    private var repeatTask: Task<Void, Never>?
    private var repeatGeneration: UInt64 = 0

    var activeKey: JoystickArrowKey? { machine.activeKey }

    init(
        deadZone: Double = 0.12,
        staleAfter: TimeInterval = 4,
        repeatDelay: TimeInterval = NSEvent.keyRepeatDelay,
        repeatInterval: TimeInterval = NSEvent.keyRepeatInterval,
        events: any JoystickArrowKeyEventSending = SystemEventSynthesizer()
    ) {
        configuredDeadZone = deadZone
        self.staleAfter = staleAfter
        self.repeatDelay = Self.duration(seconds: repeatDelay, minimum: 0)
        self.repeatInterval = Self.duration(seconds: repeatInterval, minimum: 0.01)
        self.events = events
        machine = JoystickArrowKeyStateMachine(
            deadZone: deadZone,
            staleAfter: staleAfter
        )
    }

    func update(
        _ sample: RadialInputEvent,
        deadZone: Double,
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        let previousKey = activeKey
        updateDeadZoneIfNeeded(deadZone)
        apply(machine.update(sample, at: time))
        updateRepeatTask(previousKey: previousKey)
        scheduleStaleReleaseIfNeeded()
    }

    func releaseIfStale(
        at time: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        let previousKey = activeKey
        apply(machine.resetIfStale(at: time))
        updateRepeatTask(previousKey: previousKey)
        if activeKey == nil { cancelStaleRelease() }
    }

    func stop(requireNeutral: Bool = false) {
        cancelStaleRelease()
        cancelRepeat()
        let shouldSuspend = requireNeutral || activeKey != nil || machine.isSuspendedUntilCentered
        if shouldSuspend {
            apply(machine.suspendUntilCentered())
        } else {
            apply(machine.reset())
        }
    }

    func repeatActiveKey() {
        guard let activeKey else { return }
        if case .failure(let failure) = events.repeatKey(KeyShortcut(key: activeKey.rawValue)) {
            recover(from: failure)
        }
    }

    private func updateDeadZoneIfNeeded(_ deadZone: Double) {
        guard deadZone != configuredDeadZone else { return }
        let wasSuspended = machine.isSuspendedUntilCentered
        apply(machine.reset())
        configuredDeadZone = deadZone
        machine = JoystickArrowKeyStateMachine(
            deadZone: deadZone,
            staleAfter: staleAfter
        )
        if wasSuspended { _ = machine.suspendUntilCentered() }
    }

    private func apply(_ transitions: [JoystickArrowKeyTransition]) {
        for transition in transitions {
            let shortcut = KeyShortcut(key: transition.key.rawValue)
            if case .failure(let failure) = events.send(shortcut, phase: transition.phase) {
                recover(from: failure)
                return
            }
        }
    }

    private func recover(from failure: SystemEventFailure) {
        _ = machine.suspendUntilCentered()
        cancelStaleRelease()
        cancelRepeat()
        for key in JoystickArrowKey.allCases {
            _ = events.releaseForCleanup(KeyShortcut(key: key.rawValue))
        }
        onFailure?(failure)
    }

    private func scheduleStaleReleaseIfNeeded() {
        cancelStaleRelease()
        guard activeKey != nil else { return }
        staleGeneration &+= 1
        let generation = staleGeneration
        let delay = Duration.milliseconds(Int64(staleAfter * 1_000) + 10)
        staleTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, generation == staleGeneration else { return }
            releaseIfStale()
        }
    }

    private func cancelStaleRelease() {
        staleGeneration &+= 1
        staleTask?.cancel()
        staleTask = nil
    }

    private func updateRepeatTask(previousKey: JoystickArrowKey?) {
        guard activeKey != previousKey else { return }
        cancelRepeat()
        guard let activeKey else { return }
        repeatGeneration &+= 1
        let generation = repeatGeneration
        let delay = repeatDelay
        let interval = repeatInterval
        repeatTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                while !Task.isCancelled {
                    guard let self, generation == repeatGeneration,
                        self.activeKey == activeKey
                    else { return }
                    repeatActiveKey()
                    try await Task.sleep(for: interval)
                }
            } catch {
                return
            }
        }
    }

    private func cancelRepeat() {
        repeatGeneration &+= 1
        repeatTask?.cancel()
        repeatTask = nil
    }

    private static func duration(
        seconds: TimeInterval,
        minimum: TimeInterval
    ) -> Duration {
        let normalized = seconds.isFinite ? max(seconds, minimum) : minimum
        return .milliseconds(Int64(normalized * 1_000))
    }
}
