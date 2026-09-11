import XCTest

@testable import CreatorMicroCore

final class PointerMotionEngineTests: XCTestCase {
    func testFullDeflectionMovesAlongHardwareScreenAxes() {
        let right = fullDeflection(angle: 0)
        let down = fullDeflection(angle: 0.25)
        let left = fullDeflection(angle: 0.5)
        let up = fullDeflection(angle: 0.75)

        XCTAssertGreaterThan(right.horizontal, 0)
        XCTAssertEqual(right.vertical, 0)
        XCTAssertGreaterThan(down.vertical, 0)
        XCTAssertEqual(down.horizontal, 0, accuracy: 1)
        XCTAssertLessThan(left.horizontal, 0)
        XCTAssertEqual(left.vertical, 0, accuracy: 1)
        XCTAssertEqual(up.horizontal, 0, accuracy: 1)
        XCTAssertLessThan(up.vertical, 0)
    }

    func testDeadZoneStopsMovementImmediately() {
        var engine = PointerMotionEngine(
            configuration: JoystickConfiguration(deadZone: 0.2, maximumSpeed: 1_000)
        )
        engine.update(.init(angle: 0, distance: 1), at: 1)
        _ = engine.tick(at: 1)
        XCTAssertFalse(engine.tick(at: 1.02).isStationary)

        engine.update(.init(angle: 0, distance: 0.2), at: 1.03)

        XCTAssertTrue(engine.tick(at: 1.04).isStationary)
    }

    func testStaleSampleFailsSafeAndStopsCursor() {
        var engine = PointerMotionEngine(
            configuration: JoystickConfiguration(deadZone: 0.1, maximumSpeed: 1_000),
            staleAfter: 4
        )
        engine.update(.init(angle: 0, distance: 1), at: 1)
        _ = engine.tick(at: 1)

        let stale = engine.tick(at: 5.01)

        XCTAssertTrue(stale.isStationary)
    }

    func testMovementActivityStopsAtCentreAndAfterValidatedStaleWindow() {
        var engine = PointerMotionEngine(
            configuration: JoystickConfiguration(deadZone: 0.1, maximumSpeed: 1_000),
            staleAfter: 4
        )
        engine.update(.init(angle: 0, distance: 0.8), at: 1)

        XCTAssertTrue(engine.isMoving(at: 4.99))
        XCTAssertFalse(engine.isMoving(at: 5.01))

        engine.update(.init(angle: 0, distance: 0), at: 6)
        XCTAssertFalse(engine.isMoving(at: 6))
    }

    func testDelayedTickIsCappedToAvoidCursorTeleport() {
        var engine = PointerMotionEngine(
            configuration: JoystickConfiguration(deadZone: 0.1, maximumSpeed: 1_000),
            maximumStep: 0.05
        )
        engine.update(.init(angle: 0, distance: 1), at: 1)
        _ = engine.tick(at: 1)

        let delayed = engine.tick(at: 2)

        XCTAssertLessThanOrEqual(delayed.horizontal, 50)
    }

    func testMidTravelUsesCubicFineControlCurve() {
        var engine = PointerMotionEngine(
            configuration: JoystickConfiguration(deadZone: 0, maximumSpeed: 1_000),
            maximumStep: 1
        )
        engine.update(.init(angle: 0, distance: 0.5), at: 1)
        _ = engine.tick(at: 1)

        let midTravel = engine.tick(at: 1.1)

        XCTAssertEqual(midTravel.horizontal, 12)
        XCTAssertEqual(midTravel.vertical, 0)
    }

    func testFullTravelKeepsConfiguredMaximumSpeed() {
        var engine = PointerMotionEngine(
            configuration: JoystickConfiguration(deadZone: 0.2, maximumSpeed: 1_000),
            maximumStep: 1
        )
        engine.update(.init(angle: 0, distance: 1), at: 1)
        _ = engine.tick(at: 1)

        let fullTravel = engine.tick(at: 1.1)

        XCTAssertEqual(fullTravel.horizontal, 100)
        XCTAssertEqual(fullTravel.vertical, 0)
    }
}

private func fullDeflection(angle: Double) -> PointerMotionDelta {
    var engine = PointerMotionEngine(
        configuration: JoystickConfiguration(deadZone: 0.1, maximumSpeed: 1_000)
    )
    engine.update(.init(angle: angle, distance: 1), at: 10)
    _ = engine.tick(at: 10)
    return engine.tick(at: 10.01)
}
