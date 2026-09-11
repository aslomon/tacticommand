import XCTest

@testable import CreatorMicroCore

final class JoystickArrowKeyStateMachineTests: XCTestCase {
    func testNormalizedCardinalAnglesPressMatchingArrowKeys() {
        let samples: [(angle: Double, key: JoystickArrowKey)] = [
            (0, .right),
            (0.25, .down),
            (0.5, .left),
            (0.75, .up),
            (1, .right),
        ]

        for sample in samples {
            var machine = makeMachine()

            XCTAssertEqual(
                machine.update(.init(angle: sample.angle, distance: 1), at: 1),
                [.init(key: sample.key, phase: .pressed)]
            )
        }
    }

    func testDiagonalRegionsChooseTheDominantAxis() {
        var horizontal = makeMachine()
        var vertical = makeMachine()

        XCTAssertEqual(
            horizontal.update(.init(angle: 0.10, distance: 1), at: 1),
            [.init(key: .right, phase: .pressed)]
        )
        XCTAssertEqual(
            vertical.update(.init(angle: 0.15, distance: 1), at: 1),
            [.init(key: .down, phase: .pressed)]
        )
    }

    func testHeldDirectionDoesNotEmitDuplicatePresses() {
        var machine = makeMachine()

        XCTAssertEqual(
            machine.update(.init(angle: 0, distance: 1), at: 1),
            [.init(key: .right, phase: .pressed)]
        )
        XCTAssertEqual(
            machine.update(.init(angle: 0.02, distance: 0.8), at: 2),
            []
        )
    }

    func testDirectionChangeReleasesBeforePressingReplacement() {
        var machine = makeMachine()
        _ = machine.update(.init(angle: 0, distance: 1), at: 1)

        XCTAssertEqual(
            machine.update(.init(angle: 0.25, distance: 1), at: 2),
            [
                .init(key: .right, phase: .released),
                .init(key: .down, phase: .pressed),
            ]
        )
    }

    func testDiagonalBoundaryUsesHysteresisBeforeChangingAxis() {
        var machine = makeMachine()
        _ = machine.update(.init(angle: 0.10, distance: 1), at: 1)

        XCTAssertEqual(machine.update(.init(angle: 0.13, distance: 1), at: 2), [])
        XCTAssertEqual(
            machine.update(.init(angle: 0.16, distance: 1), at: 3),
            [
                .init(key: .right, phase: .released),
                .init(key: .down, phase: .pressed),
            ]
        )
    }

    func testDeadZoneReleasesActiveKeyAndStaysIdle() {
        var machine = makeMachine(deadZone: 0.2)
        _ = machine.update(.init(angle: 0.5, distance: 1), at: 1)

        XCTAssertEqual(
            machine.update(.init(angle: 0.5, distance: 0.2), at: 2),
            [.init(key: .left, phase: .released)]
        )
        XCTAssertEqual(
            machine.update(.init(angle: 0, distance: 0.1), at: 3),
            []
        )
        XCTAssertNil(machine.activeKey)
    }

    func testStaleResetReleasesOnceAfterTimeout() {
        var machine = makeMachine(staleAfter: 4)
        _ = machine.update(.init(angle: 0.75, distance: 1), at: 10)

        XCTAssertEqual(machine.resetIfStale(at: 14), [])
        XCTAssertEqual(
            machine.resetIfStale(at: 14.01),
            [.init(key: .up, phase: .released)]
        )
        XCTAssertEqual(machine.resetIfStale(at: 20), [])
        XCTAssertNil(machine.activeKey)
    }

    func testExplicitResetBalancesActivePress() {
        var machine = makeMachine()
        _ = machine.update(.init(angle: 0.25, distance: 1), at: 1)

        XCTAssertEqual(
            machine.reset(),
            [.init(key: .down, phase: .released)]
        )
        XCTAssertEqual(machine.reset(), [])
    }

    func testSuspensionRequiresCenterBeforeAnotherDirectionCanPress() {
        var machine = makeMachine()
        _ = machine.update(.init(angle: 0, distance: 1), at: 1)

        XCTAssertEqual(
            machine.suspendUntilCentered(),
            [.init(key: .right, phase: .released)]
        )
        XCTAssertEqual(machine.update(.init(angle: 0.25, distance: 1), at: 2), [])
        XCTAssertTrue(machine.isSuspendedUntilCentered)
        XCTAssertEqual(machine.update(.init(angle: 0.25, distance: 0), at: 3), [])
        XCTAssertFalse(machine.isSuspendedUntilCentered)
        XCTAssertEqual(
            machine.update(.init(angle: 0.25, distance: 1), at: 4),
            [.init(key: .down, phase: .pressed)]
        )
    }

    func testInvalidSamplesFailSafeByReleasing() {
        var machine = makeMachine()
        _ = machine.update(.init(angle: 0, distance: 1), at: 1)

        XCTAssertEqual(
            machine.update(.init(angle: .infinity, distance: 1), at: 2),
            [.init(key: .right, phase: .released)]
        )
        XCTAssertEqual(
            machine.update(.init(angle: 0, distance: .nan), at: 3),
            []
        )
    }

    func testPublicValuesAreSendable() {
        assertSendable(JoystickArrowKey.self)
        assertSendable(JoystickArrowKeyTransition.self)
        assertSendable(JoystickArrowKeyStateMachine.self)
    }

    private func makeMachine(
        deadZone: Double = 0.15,
        staleAfter: TimeInterval = 4
    ) -> JoystickArrowKeyStateMachine {
        JoystickArrowKeyStateMachine(
            deadZone: deadZone,
            staleAfter: staleAfter
        )
    }

    private func assertSendable<Value: Sendable>(_: Value.Type) {}
}
