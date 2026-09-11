import CreatorMicroCore
import Foundation

@MainActor
final class JoystickPointerController {
    var onFailure: ((SystemEventFailure) -> Void)?

    private let events: SystemEventSynthesizer
    private var engine: PointerMotionEngine
    private var worker: Task<Void, Never>?
    private var workerGeneration: UInt64 = 0
    private var lastFailure: SystemEventFailure?

    var isRunning: Bool { worker != nil }

    init(
        configuration: JoystickConfiguration = JoystickConfiguration(),
        events: SystemEventSynthesizer = SystemEventSynthesizer()
    ) {
        self.events = events
        engine = PointerMotionEngine(configuration: configuration)
    }

    func update(
        _ sample: RadialInputEvent,
        configuration: JoystickConfiguration
    ) {
        engine.update(configuration: configuration)
        engine.update(sample, at: ProcessInfo.processInfo.systemUptime)
        startIfNeeded()
    }

    func stop() {
        workerGeneration &+= 1
        worker?.cancel()
        worker = nil
        engine.stop()
        lastFailure = nil
    }

    private func startIfNeeded() {
        guard worker == nil else { return }
        workerGeneration &+= 1
        let generation = workerGeneration
        worker = Task { [weak self] in
            await self?.runMotionLoop(generation: generation)
        }
    }

    private func runMotionLoop(generation: UInt64) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(11))
            } catch {
                break
            }
            guard tick() else { break }
        }
        guard generation == workerGeneration else { return }
        worker = nil
    }

    private func tick() -> Bool {
        let time = ProcessInfo.processInfo.systemUptime
        guard engine.isMoving(at: time) else {
            engine.stop()
            return false
        }
        let delta = engine.tick(at: time)
        guard !delta.isStationary else { return true }
        let result = events.perform(
            .move(horizontal: delta.horizontal, vertical: delta.vertical)
        )
        if case .failure(let failure) = result, failure != lastFailure {
            lastFailure = failure
            onFailure?(failure)
        } else if case .success = result {
            lastFailure = nil
        }
        return true
    }
}
