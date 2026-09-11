import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDeviceCoordinatorTests: XCTestCase {
    func testStatusRoundTripMarksConnectionVerifiedAndForwardsInput() async throws {
        let transport = SimulatedMicroTransport(kind: .usb)
        let connector = QueueTransportConnector(transports: [transport])
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()

        try await collector.waitForConnecting()
        try await waitForWrite(on: transport)
        await transport.injectMessage(statusPayload(layer: 5, identifier: 99))
        try await Task.sleep(for: .milliseconds(20))
        let unverifiedStates = await collector.connectedStates()
        XCTAssertTrue(unverifiedStates.isEmpty)
        await transport.injectMessage(statusPayload(layer: 2))
        try await collector.waitForConnectedCount(1)
        await assertVerifiedUSBConnection(collector)

        await transport.injectMessage(
            Data(#"{"m":"v.oai.hid","p":{"k":"ACT12","act":1}}"#.utf8)
        )
        try await collector.waitForInputCount(1)
        await assertForwardedReturnInput(collector)
        await coordinator.stop()
        await collector.stop()
    }

    private func assertVerifiedUSBConnection(_ collector: UpdateCollector) async {
        let connected = await collector.connectedStates()
        XCTAssertEqual(connected.first?.transport, .usb)
        XCTAssertEqual(
            connected.first?.status,
            DeviceStatus(
                version: "0.4.1",
                profileIndex: 0,
                layerIndex: 2,
                batteryPercentage: 76,
                isCharging: false
            )
        )
    }

    private func assertForwardedReturnInput(_ collector: UpdateCollector) async {
        let inputs = await collector.inputEvents()
        XCTAssertEqual(
            inputs,
            [
                MicroInputEvent(
                    control: .action12,
                    phase: .pressed,
                    rawActivity: 1,
                    agentIndex: nil
                )
            ]
        )
    }

    func testReconnectsAfterTransportEndsAndVerifiesReplacement() async throws {
        let first = SimulatedMicroTransport(kind: .usb)
        let second = SimulatedMicroTransport(kind: .bluetoothLowEnergy)
        let connector = QueueTransportConnector(transports: [first, second])
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .milliseconds(1),
            statusTimeout: .seconds(1)
        )
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()

        try await waitForWrite(on: first)
        await first.injectMessage(statusPayload(layer: 0))
        try await collector.waitForConnectedCount(1)
        await first.finishIncomingReports()
        try await waitForWrite(on: second)
        await second.injectMessage(statusPayload(layer: 4))
        try await collector.waitForConnectedCount(2)

        let connected = await collector.connectedStates()
        XCTAssertEqual(connected.map(\.transport), [.usb, .bluetoothLowEnergy])
        XCTAssertEqual(connected.last?.status?.layerIndex, 4)
        await coordinator.stop()
        await collector.stop()
    }

    func testExternalPayloadUsesActiveTransportFraming() async throws {
        let transport = SimulatedMicroTransport(kind: .bluetoothLowEnergy)
        let connector = QueueTransportConnector(transports: [transport])
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(statusPayload(layer: 1))
        try await collector.waitForConnectedCount(1)
        await transport.clearCapturedWrites()

        let payload = try LightingPayloadBuilder.uniformAgentStatus(color: .green)
        try await coordinator.send(payload: payload)
        let reports = await transport.capturedWrites()

        XCTAssertFalse(reports.isEmpty)
        XCTAssertTrue(
            reports.allSatisfy { report in
                report.count == MicroProtocolConstants.bluetoothReportLength
                    && report.first == MicroProtocolConstants.reportIdentifier
            })
        await coordinator.stop()
        await collector.stop()
    }

    func testConnectorFailurePublishesUnavailableInsteadOfTerminating() async throws {
        let connector = QueueTransportConnector(transports: [])
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()

        try await collector.waitForUnavailableCount(1)

        let reasons = await collector.unavailableReasons()
        XCTAssertEqual(reasons, ["Creator Micro 2 was not found."])
        await coordinator.stop()
        await collector.stop()
    }

    func testCancelledSubscriberDoesNotTerminateReplacementStream() async throws {
        let connector = QueueTransportConnector(transports: [])
        let coordinator = MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let first = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await first.start()
        await first.stop()

        let replacement = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await replacement.start()
        await coordinator.start()
        try await replacement.waitForUnavailableCount(1)

        let reasons = await replacement.unavailableReasons()
        XCTAssertEqual(reasons, ["Creator Micro 2 was not found."])
        await coordinator.stop()
        await replacement.stop()
    }

}

private actor QueueTransportConnector: MicroTransportConnector {
    private var transports: [SimulatedMicroTransport]

    init(transports: [SimulatedMicroTransport]) {
        self.transports = transports
    }

    func connect() async throws -> any MicroTransport {
        guard !transports.isEmpty else {
            throw MicroConnectionError.deviceNotFound
        }
        return transports.removeFirst()
    }
}

private actor UpdateCollector {
    private let stream: AsyncStream<MicroCoordinatorUpdate>
    private var updates: [MicroCoordinatorUpdate] = []
    private var task: Task<Void, Never>?

    init(stream: AsyncStream<MicroCoordinatorUpdate>) {
        self.stream = stream
    }

    func start() {
        task = Task {
            for await update in stream {
                updates.append(update)
            }
        }
    }

    func stop() async {
        task?.cancel()
        await task?.value
        task = nil
    }

    func waitForConnectedCount(_ expected: Int) async throws {
        for _ in 0..<200 {
            if connectedStates().count >= expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }

    func waitForConnecting() async throws {
        for _ in 0..<200 {
            if updates.contains(.connection(.connecting)) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }

    func waitForInputCount(_ expected: Int) async throws {
        for _ in 0..<200 {
            if inputEvents().count >= expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }

    func waitForUnavailableCount(_ expected: Int) async throws {
        for _ in 0..<200 {
            if unavailableReasons().count >= expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }

    func connectedStates() -> [(transport: MicroTransportKind, status: DeviceStatus?)] {
        updates.compactMap { update in
            guard case .connection(.connected(let transport, let status)) = update else {
                return nil
            }
            return (transport, status)
        }
    }

    func inputEvents() -> [MicroInputEvent] {
        updates.compactMap { update in
            guard case .event(.input(let event)) = update else { return nil }
            return event
        }
    }

    func unavailableReasons() -> [String] {
        updates.compactMap { update in
            guard case .connection(.unavailable(let reason)) = update else {
                return nil
            }
            return reason
        }
    }
}

private enum TestFailure: Error {
    case timeout
}

private func statusPayload(layer: Int, identifier: Int = 1) -> Data {
    Data(
        "{\"result\":{\"version\":\"0.4.1\",\"profile_index\":0,\"layer_index\":\(layer),\"battery\":76,\"is_charging\":false},\"id\":\(identifier)}"
            .utf8
    )
}

private func waitForWrite(on transport: SimulatedMicroTransport) async throws {
    for _ in 0..<200 {
        if !(await transport.capturedWrites()).isEmpty { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw TestFailure.timeout
}
