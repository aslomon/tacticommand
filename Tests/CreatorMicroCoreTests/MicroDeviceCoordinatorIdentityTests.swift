import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDeviceCoordinatorIdentityTests: XCTestCase {
    func testIdentitySnapshotReflectsObservedCreatorProductIdentifier() async throws {
        let transport = SimulatedMicroTransport(kind: .usb, productIdentifier: 0x8298)
        let coordinator = MicroDeviceCoordinator(
            connector: QueueTransportConnector(transports: [transport]),
            retryDelay: .seconds(30), statusTimeout: .seconds(1)
        )
        let identities = IdentityCollector(stream: await coordinator.makeIdentityUpdateStream())
        await identities.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(statusPayload(layer: 2))
        try await identities.waitForNonNilCount(1)

        let snapshot = try await identities.latestNonNil()
        XCTAssertEqual(snapshot.productIdentifier, 0x8298)
        XCTAssertEqual(snapshot.capability.model, .creator13)
        await coordinator.stop()
        await identities.stop()
    }

    func testUnknownProductIdentifierNeverClaimsCreatorCapability() async throws {
        let transport = SimulatedMicroTransport(kind: .usb, productIdentifier: nil)
        let coordinator = MicroDeviceCoordinator(
            connector: QueueTransportConnector(transports: [transport]),
            retryDelay: .seconds(30), statusTimeout: .seconds(1)
        )
        let identities = IdentityCollector(stream: await coordinator.makeIdentityUpdateStream())
        await identities.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(statusPayload(layer: 0))
        try await identities.waitForNonNilCount(1)

        let snapshot = try await identities.latestNonNil()
        XCTAssertNil(snapshot.productIdentifier)
        XCTAssertEqual(snapshot.capability.model, .unknown)
        await coordinator.stop()
        await identities.stop()
    }

    func testDisconnectClearsTheIdentitySnapshot() async throws {
        let transport = SimulatedMicroTransport(kind: .usb, productIdentifier: 0x8360)
        let coordinator = MicroDeviceCoordinator(
            connector: QueueTransportConnector(transports: [transport]),
            retryDelay: .seconds(30), statusTimeout: .seconds(1)
        )
        let identities = IdentityCollector(stream: await coordinator.makeIdentityUpdateStream())
        await identities.start()
        await coordinator.start()
        try await waitForWrite(on: transport)
        await transport.injectMessage(statusPayload(layer: 0))
        try await identities.waitForNonNilCount(1)

        await coordinator.stop()
        try await identities.waitForTrailingNil()
        await identities.stop()
    }
}

actor IdentityCollector {
    private let stream: AsyncStream<DeviceIdentitySnapshot?>
    private var snapshots: [DeviceIdentitySnapshot?] = []
    private var task: Task<Void, Never>?

    init(stream: AsyncStream<DeviceIdentitySnapshot?>) {
        self.stream = stream
    }

    func start() {
        task = Task {
            for await snapshot in stream {
                snapshots.append(snapshot)
            }
        }
    }

    func stop() async {
        task?.cancel()
        await task?.value
        task = nil
    }

    func waitForNonNilCount(_ expected: Int) async throws {
        for _ in 0..<200 {
            if snapshots.compactMap({ $0 }).count >= expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }

    func waitForTrailingNil() async throws {
        for _ in 0..<200 {
            if case .some(.none) = snapshots.last { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw TestFailure.timeout
    }

    func latestNonNil() throws -> DeviceIdentitySnapshot {
        guard let snapshot = snapshots.compactMap({ $0 }).last else {
            throw TestFailure.timeout
        }
        return snapshot
    }
}
