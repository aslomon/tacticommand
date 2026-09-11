import Foundation

enum BoundedShutdownOutcome: Equatable, Sendable {
    case completed
    case timedOut
}

struct BoundedShutdown: Sendable {
    let timeout: Duration

    func run(
        _ operation: @escaping @Sendable () async -> Void
    ) async -> BoundedShutdownOutcome {
        let outcomeGate = BoundedShutdownOutcomeGate()
        let operationTask = Task {
            await operation()
            await outcomeGate.resolve(.completed)
        }
        let timeoutTask = Task {
            do {
                try await Task.sleep(for: timeout)
                await outcomeGate.resolve(.timedOut)
            } catch {
                return
            }
        }
        let outcome = await outcomeGate.value()
        operationTask.cancel()
        timeoutTask.cancel()
        return outcome
    }
}

actor BoundedShutdownOutcomeGate {
    private var outcome: BoundedShutdownOutcome?
    private var waiter: CheckedContinuation<BoundedShutdownOutcome, Never>?

    func resolve(_ outcome: BoundedShutdownOutcome) {
        guard self.outcome == nil else { return }
        self.outcome = outcome
        waiter?.resume(returning: outcome)
        waiter = nil
    }

    func value() async -> BoundedShutdownOutcome {
        if let outcome { return outcome }
        return await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }
}

enum ApplicationTerminationDecision: Equatable {
    case beginCleanup
    case terminateImmediately
}

struct ApplicationTerminationPolicy {
    private var cleanupStarted = false

    mutating func request() -> ApplicationTerminationDecision {
        guard !cleanupStarted else { return .terminateImmediately }
        cleanupStarted = true
        return .beginCleanup
    }
}

enum ApplicationQuitCommand {
    static let title = "Quit TactiCommand"
    static let keyEquivalent: Character = "q"
}
