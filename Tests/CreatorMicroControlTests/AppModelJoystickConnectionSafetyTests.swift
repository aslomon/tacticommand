import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelJoystickConnectionSafetyTests: XCTestCase {
    func testConnectionLossRequiresFreshCenterBeforeArrowInputRearms() async {
        let fixture = makeConnectionSafetyFixture()
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0)))

        fixture.model.handleJoystickSafety(.init(sequence: 1, state: .disconnected))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))

        XCTAssertTrue(fixture.events.sent.isEmpty)
        await fixture.model.handle(.radial(.init(angle: 0, distance: 0)))
        await fixture.model.handle(.radial(.init(angle: 0, distance: 1)))
        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
    }

    func testStaleCenterCannotRearmAfterNewerDisconnect() async {
        let fixture = makeConnectionSafetyFixture()
        fixture.model.handleJoystickSafety(.init(sequence: 2, state: .disconnected))
        fixture.model.handleJoystickRadial(
            .init(
                sequence: 1,
                connectionSequence: 1,
                input: .init(angle: 0, distance: 0)
            )
        )
        fixture.model.handleJoystickSafety(
            .init(sequence: 3, state: .connected(transport: .usb, status: nil))
        )

        fixture.model.handleJoystickRadial(
            .init(
                sequence: 4,
                connectionSequence: 3,
                input: .init(angle: 0, distance: 1)
            )
        )
        XCTAssertTrue(fixture.events.sent.isEmpty)

        sendCenterThenRight(to: fixture.model, connectionSequence: 3)
        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
    }

    func testNewConnectionRadialWaitsForMatchingSafetyEpoch() async {
        let fixture = makeConnectionSafetyFixture()
        fixture.model.handleJoystickSafety(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )

        fixture.model.handleJoystickRadial(
            .init(
                sequence: 13,
                connectionSequence: 12,
                input: .init(angle: 0, distance: 1)
            )
        )
        XCTAssertTrue(fixture.events.sent.isEmpty)

        fixture.model.handleJoystickSafety(.init(sequence: 10, state: .disconnected))
        fixture.model.handleJoystickSafety(
            .init(sequence: 12, state: .connected(transport: .usb, status: nil))
        )
        sendCenterThenRight(to: fixture.model, connectionSequence: 12)
        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
    }

    func testManualReconnectIgnoresQueuedOldConnectionAndRadial() async {
        let fixture = makeConnectionSafetyFixture()
        fixture.model.handleJoystickSafety(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )
        fixture.model.handleJoystickRadial(
            .init(
                sequence: 6,
                connectionSequence: 5,
                input: .init(angle: 0, distance: 0)
            )
        )

        fixture.model.beginReconnect()
        fixture.model.handleJoystickSafety(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )
        sendCenterThenRight(to: fixture.model, connectionSequence: 5)

        XCTAssertTrue(fixture.events.sent.isEmpty)
        await fixture.model.shutdown()
    }

    func testAccessibilityRecoveryKeepsVerifiedDeviceEpochAndRearms() async {
        let fixture = makeConnectionSafetyFixture()
        fixture.model.handleJoystickSafety(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )
        fixture.model.applySystemAccess(
            .init(accessibility: .denied, inputMonitoring: .granted)
        )
        fixture.model.applySystemAccess(
            .init(accessibility: .granted, inputMonitoring: .granted)
        )

        sendCenterThenRight(to: fixture.model, connectionSequence: 5)

        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
    }

    func testRapidInputMonitoringRecoveryKeepsVerifiedEpoch() async {
        let fixture = makeConnectionSafetyFixture()
        fixture.model.hasStarted = true
        fixture.model.isReady = true
        fixture.model.runtimeTask = Task {}
        fixture.model.handleJoystickSafety(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )

        fixture.model.applySystemAccess(
            .init(accessibility: .granted, inputMonitoring: .denied)
        )
        fixture.model.applySystemAccess(
            .init(accessibility: .granted, inputMonitoring: .granted)
        )
        for _ in 0..<20 where fixture.model.systemAccessReconciliationTask != nil {
            await Task.yield()
        }
        sendCenterThenRight(to: fixture.model, connectionSequence: 5)

        XCTAssertEqual(fixture.events.sent.last, .init(key: "right", phase: .pressed))
        await fixture.model.shutdown()
    }

    func testConfigurationBoundaryDiscardsAlreadyDeliveredRadialSamples() async {
        let fixture = makeConnectionSafetyFixture()
        let radial = AsyncStream<SequencedRadialUpdate>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        let safety = AsyncStream<SequencedConnectionUpdate>.makeStream(
            bufferingPolicy: .unbounded
        )
        fixture.model.startJoystickRuntime(
            radialUpdates: radial.stream,
            safetyUpdates: safety.stream
        )
        safety.continuation.yield(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )
        for _ in 0..<20 where !fixture.model.isJoystickConnectionVerified {
            await Task.yield()
        }

        radial.continuation.yield(
            .init(
                sequence: 6,
                connectionSequence: 5,
                input: .init(angle: 0, distance: 0)
            )
        )
        radial.continuation.yield(
            .init(
                sequence: 7,
                connectionSequence: 5,
                input: .init(angle: 0, distance: 1)
            )
        )
        fixture.model.setLayerJoystickDeadZone(0.03)
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(fixture.events.sent.isEmpty)
        radial.continuation.finish()
        safety.continuation.finish()
        await fixture.model.shutdown()
    }

    func testLocalBoundaryRejectsAnUpdateFromThePreviousRadialGeneration() async {
        let fixture = makeConnectionSafetyFixture()
        fixture.model.handleJoystickSafety(
            .init(sequence: 5, state: .connected(transport: .usb, status: nil))
        )
        let previousGeneration = fixture.model.joystickRadialGeneration

        fixture.model.setLayerJoystickDeadZone(0.03)
        fixture.model.handleJoystickRadial(
            .init(
                sequence: 6,
                connectionSequence: 5,
                input: .init(angle: 0, distance: 0)
            ),
            generation: previousGeneration
        )
        fixture.model.handleJoystickRadial(
            .init(
                sequence: 7,
                connectionSequence: 5,
                input: .init(angle: 0, distance: 1)
            ),
            generation: previousGeneration
        )

        XCTAssertTrue(fixture.events.sent.isEmpty)
        await fixture.model.shutdown()
    }

    private func sendCenterThenRight(to model: AppModel, connectionSequence: UInt64) {
        model.handleJoystickRadial(
            .init(
                sequence: connectionSequence + 1,
                connectionSequence: connectionSequence,
                input: .init(angle: 0, distance: 0)
            )
        )
        model.handleJoystickRadial(
            .init(
                sequence: connectionSequence + 2,
                connectionSequence: connectionSequence,
                input: .init(angle: 0, distance: 1)
            )
        )
    }

    private func makeConnectionSafetyFixture() -> ConnectionSafetyFixture {
        let events = ConnectionSafetyEvents()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let model = AppModel(
            configurationStore: ConfigurationStore(
                fileURL: directory.appendingPathComponent("configuration.json")
            ),
            initialSystemAccess: SystemAccessSnapshot(
                accessibility: .granted,
                inputMonitoring: .granted
            ),
            arrowKeyController: JoystickArrowKeyController(events: events)
        )
        return ConnectionSafetyFixture(model: model, events: events)
    }
}

@MainActor
private struct ConnectionSafetyFixture {
    let model: AppModel
    let events: ConnectionSafetyEvents
}

@MainActor
private final class ConnectionSafetyEvents: JoystickArrowKeyEventSending {
    struct Event: Equatable {
        let key: String
        let phase: ButtonPhase
    }

    private(set) var sent: [Event] = []

    func send(_ shortcut: KeyShortcut, phase: ButtonPhase) -> Result<Void, SystemEventFailure> {
        sent.append(.init(key: shortcut.key, phase: phase))
        return .success(())
    }

    func releaseForCleanup(_ shortcut: KeyShortcut) -> Result<Void, SystemEventFailure> {
        .success(())
    }

    func repeatKey(_ shortcut: KeyShortcut) -> Result<Void, SystemEventFailure> {
        .success(())
    }
}
