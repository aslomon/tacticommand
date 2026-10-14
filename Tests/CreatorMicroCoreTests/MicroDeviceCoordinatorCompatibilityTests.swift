import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDeviceCoordinatorCompatibilityTests: XCTestCase {
    func testStatus404FailsImmediatelyWithFirmwareUpdateGuidance() async throws {
        let transport = SimulatedMicroTransport(kind: .usb)
        let coordinator = MicroDeviceCoordinator(
            connector: QueueTransportConnector(transports: [transport]),
            retryDelay: .seconds(30), statusTimeout: .seconds(30))
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(
            Data(#"{"method":"device.status","id":1,"error":{"code":404,"message":"Method not found"}}"#.utf8))
        try await collector.waitForUnavailableCount(1)
        let reasons = await collector.unavailableReasons()
        XCTAssertEqual(
            reasons,
            ["This firmware does not support device.status. Install the official firmware update for your controller."])
        let connected = await collector.connectedStates()
        XCTAssertTrue(connected.isEmpty)
        await coordinator.stop()
        await collector.stop()
    }

    func testUncorrelatedStatusErrorCannotRejectHandshake() async throws {
        let transport = SimulatedMicroTransport(kind: .usb)
        let coordinator = MicroDeviceCoordinator(
            connector: QueueTransportConnector(transports: [transport]),
            retryDelay: .seconds(30), statusTimeout: .seconds(1))
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(
            Data(#"{"method":"device.status","id":99,"error":{"code":404,"message":"Method not found"}}"#.utf8))
        await transport.injectMessage(statusPayload(layer: 1))
        try await collector.waitForConnectedCount(1)
        let unavailable = await collector.unavailableReasons()
        XCTAssertTrue(unavailable.isEmpty)
        await coordinator.stop()
        await collector.stop()
    }
}
