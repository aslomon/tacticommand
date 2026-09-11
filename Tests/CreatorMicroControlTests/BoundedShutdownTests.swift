import Foundation
import XCTest

@testable import CreatorMicroControl

final class BoundedShutdownTests: XCTestCase {
    func testCompletedCleanupReturnsBeforeDeadline() async {
        let shutdown = BoundedShutdown(timeout: .seconds(1))

        let outcome = await shutdown.run {}

        XCTAssertEqual(outcome, .completed)
    }

    func testHangingCleanupTimesOutAndReceivesCancellation() async throws {
        let probe = ShutdownCancellationProbe()
        let shutdown = BoundedShutdown(timeout: .milliseconds(20))
        let clock = ContinuousClock()
        let startedAt = clock.now

        let outcome = await shutdown.run {
            await probe.waitForCancellation()
        }

        XCTAssertEqual(outcome, .timedOut)
        XCTAssertLessThan(startedAt.duration(to: clock.now), .seconds(1))
        try await probe.waitUntilCancelled()
    }

    func testFirstShutdownOutcomeCannotBeOverwritten() async {
        let gate = BoundedShutdownOutcomeGate()
        await gate.resolve(.completed)
        await gate.resolve(.timedOut)

        let outcome = await gate.value()

        XCTAssertEqual(outcome, .completed)
    }

    func testRepeatedTerminationRequestTerminatesImmediately() {
        var policy = ApplicationTerminationPolicy()

        XCTAssertEqual(policy.request(), .beginCleanup)
        XCTAssertEqual(policy.request(), .terminateImmediately)
    }

    func testQuitCommandHasVisibleLabelAndStandardShortcut() {
        XCTAssertEqual(ApplicationQuitCommand.title, "Quit TactiCommand")
        XCTAssertEqual(ApplicationQuitCommand.keyEquivalent, "q")
    }
}

private actor ShutdownCancellationProbe {
    private var wasCancelled = false

    func waitForCancellation() async {
        do {
            try await Task.sleep(for: .seconds(60))
        } catch {
            wasCancelled = true
        }
    }

    func waitUntilCancelled() async throws {
        for _ in 0..<100 {
            if wasCancelled { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ShutdownTestFailure.timeout
    }
}

private enum ShutdownTestFailure: Error {
    case timeout
}
