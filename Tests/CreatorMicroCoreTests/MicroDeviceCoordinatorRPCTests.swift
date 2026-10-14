import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDeviceCoordinatorRPCTests: XCTestCase {
    func testRPCMatchesIDAndMethodWhileInputContinues() async throws {
        let (coordinator, transport, collector) = try await connected()
        let request = Task { try await coordinator.request(method: "fs.read") }
        try await waitForPending(on: coordinator)
        await transport.injectMessage(Data(#"{"id":2,"method":"fs.write","result":null}"#.utf8))
        await transport.injectMessage(Data(#"{"m":"v.oai.hid","p":{"k":"AG00","act":1}}"#.utf8))
        try await collector.waitForInputCount(1)
        await transport.injectMessage(Data(#"{"i":2,"m":"fs.read","result":{"data":"keymap"}}"#.utf8))
        let response = try await request.value
        XCTAssertEqual(response["data"], .string("keymap"))
        await coordinator.stop()
        await collector.stop()
    }

    func testTimeoutConsumesIDAndLateResponseCannotCompleteNextRequest() async throws {
        let (coordinator, transport, collector) = try await connected()
        do {
            _ = try await coordinator.request(method: "fs.read", timeout: .milliseconds(20))
            XCTFail()
        } catch MicroRPCError.timeout {}
        let request = Task { try await coordinator.request(method: "fs.read") }
        try await waitForPending(on: coordinator)
        await transport.injectMessage(Data(#"{"id":2,"method":"fs.read","result":"old"}"#.utf8))
        await transport.injectMessage(Data(#"{"id":3,"method":"fs.read","result":"new"}"#.utf8))
        let response = try await request.value
        XCTAssertEqual(response, .string("new"))
        await coordinator.stop()
        await collector.stop()
    }

    func testDisconnectAndCancellationFinishPendingRequests() async throws {
        let (coordinator, _, collector) = try await connected()
        let cancelled = Task { try await coordinator.request(method: "fs.read") }
        try await waitForPending(on: coordinator)
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail()
        } catch is CancellationError {}
        let request = Task { try await coordinator.request(method: "fs.read") }
        try await waitForPending(on: coordinator)
        await coordinator.stop()
        do {
            _ = try await request.value
            XCTFail()
        } catch MicroConnectionError.transportDisconnected {}
        await collector.stop()
    }

    private func connected() async throws -> (MicroDeviceCoordinator, SimulatedMicroTransport, UpdateCollector) {
        let transport = SimulatedMicroTransport(productIdentifier: 0x8298)
        let coordinator = MicroDeviceCoordinator(connector: QueueTransportConnector(transports: [transport]))
        let collector = UpdateCollector(stream: await coordinator.makeUpdateStream())
        await collector.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(statusPayload(layer: 2))
        try await collector.waitForConnectedCount(1)
        return (coordinator, transport, collector)
    }

    private func waitForPending(on coordinator: MicroDeviceCoordinator) async throws {
        for _ in 0..<100 {
            if await !coordinator.pendingRPC.isEmpty { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }
}
