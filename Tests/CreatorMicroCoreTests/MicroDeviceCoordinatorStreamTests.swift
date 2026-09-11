import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroDeviceCoordinatorStreamTests: XCTestCase {
    func testDiscreteStreamKeepsReleaseAcrossCompletedRadialBurst() async throws {
        let transport = SimulatedMicroTransport(kind: .usb)
        let coordinator = MicroDeviceCoordinator(
            connector: StreamTestConnector(transport: transport),
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let delayedStream = await coordinator.makeDiscreteUpdateStream()
        let observer = StreamTestCollector(stream: await coordinator.makeDiscreteUpdateStream())
        await observer.start()
        await coordinator.start()
        try await waitForStreamTestWrite(on: transport)
        await transport.injectMessage(streamTestStatusPayload())
        try await waitForStreamTestConnection(coordinator)

        await transport.injectMessage(streamTestInputPayload(control: "ACT12", activity: 1))
        await transport.injectMessage(streamTestInputPayload(control: "ACT12", activity: 0))
        for index in 0..<300 {
            await transport.injectMessage(streamTestRadialPayload(index: index))
        }
        await transport.injectMessage(streamTestInputPayload(control: "ACT11", activity: 1))
        try await observer.waitForInputCount(3)

        let snapshot = try await collectStreamTestSnapshot(from: delayedStream, inputCount: 3)
        XCTAssertEqual(snapshot.inputs.map(\.control), [.action12, .action12, .action11])
        XCTAssertEqual(snapshot.inputs.map(\.phase), [.pressed, .released, .pressed])
        XCTAssertEqual(snapshot.radialCount, 0)
        await coordinator.stop()
        await observer.stop()
    }

    func testUnverifiedTransportCannotPublishInputOrRadialEvents() async throws {
        let transport = SimulatedMicroTransport(kind: .usb)
        let coordinator = MicroDeviceCoordinator(
            connector: StreamTestConnector(transport: transport),
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let observer = StreamTestCollector(stream: await coordinator.makeUpdateStream())
        await observer.start()
        await coordinator.start()
        try await waitForStreamTestWrite(on: transport)

        await transport.injectMessage(streamTestInputPayload(control: "ACT12", activity: 1))
        await transport.injectMessage(streamTestRadialPayload(index: 0))
        await transport.injectMessage(streamTestStatusPayload())
        try await observer.waitForConnected()

        let unverifiedSnapshot = await observer.snapshot()
        XCTAssertEqual(unverifiedSnapshot.inputCount, 0)
        XCTAssertEqual(unverifiedSnapshot.radialCount, 0)

        await transport.injectMessage(streamTestInputPayload(control: "ACT12", activity: 1))
        await transport.injectMessage(streamTestRadialPayload(index: 1))
        try await observer.waitForInputCount(1)
        try await observer.waitForRadialCount(1)
        await coordinator.stop()
        await observer.stop()
    }

    func testLateSafetySubscriberUsesVerifiedConnectionEpoch() async throws {
        let transport = SimulatedMicroTransport(kind: .usb)
        let coordinator = MicroDeviceCoordinator(
            connector: StreamTestConnector(transport: transport),
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
        let observer = StreamTestCollector(stream: await coordinator.makeUpdateStream())
        await observer.start()
        await coordinator.start()
        try await waitForStreamTestWrite(on: transport)
        await transport.injectMessage(streamTestStatusPayload())
        try await observer.waitForConnected()
        await transport.injectMessage(streamTestInputPayload(control: "ACT12", activity: 1))
        try await observer.waitForInputCount(1)

        var safetyIterator = await coordinator.makeJoystickSafetyUpdateStream().makeAsyncIterator()
        var radialIterator = await coordinator.makeRadialUpdateStream().makeAsyncIterator()
        guard let safety = await safetyIterator.next() else {
            throw StreamTestFailure.timeout
        }
        await transport.injectMessage(streamTestRadialPayload(index: 1))
        guard let radial = await radialIterator.next() else {
            throw StreamTestFailure.timeout
        }

        XCTAssertEqual(safety.sequence, radial.connectionSequence)
        await coordinator.stop()
        await observer.stop()
    }
}

private actor StreamTestConnector: MicroTransportConnector {
    private var transport: SimulatedMicroTransport?

    init(transport: SimulatedMicroTransport) {
        self.transport = transport
    }

    func connect() async throws -> any MicroTransport {
        guard let transport else { throw MicroConnectionError.deviceNotFound }
        self.transport = nil
        return transport
    }
}

private actor StreamTestCollector {
    private let stream: AsyncStream<MicroCoordinatorUpdate>
    private var inputCount = 0
    private var radialCount = 0
    private var connectedCount = 0
    private var task: Task<Void, Never>?

    init(stream: AsyncStream<MicroCoordinatorUpdate>) {
        self.stream = stream
    }

    func start() {
        task = Task {
            for await update in stream {
                switch update {
                case .event(.input): inputCount += 1
                case .event(.radial): radialCount += 1
                case .connection(.connected): connectedCount += 1
                default: break
                }
            }
        }
    }

    func waitForInputCount(_ expected: Int) async throws {
        try await waitUntil { inputCount >= expected }
    }

    func waitForRadialCount(_ expected: Int) async throws {
        try await waitUntil { radialCount >= expected }
    }

    func waitForConnected() async throws {
        try await waitUntil { connectedCount > 0 }
    }

    func snapshot() -> (inputCount: Int, radialCount: Int) {
        (inputCount, radialCount)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw StreamTestFailure.timeout
    }

    func stop() async {
        task?.cancel()
        await task?.value
    }
}

private struct StreamTestSnapshot: Sendable {
    let inputs: [MicroInputEvent]
    let radialCount: Int
}

private func collectStreamTestSnapshot(
    from stream: AsyncStream<MicroCoordinatorUpdate>,
    inputCount: Int
) async throws -> StreamTestSnapshot {
    try await withThrowingTaskGroup(of: StreamTestSnapshot.self) { group in
        group.addTask {
            var inputs: [MicroInputEvent] = []
            var radialCount = 0
            for await update in stream {
                switch update {
                case .event(.input(let input)):
                    inputs.append(input)
                    if inputs.count == inputCount {
                        return StreamTestSnapshot(inputs: inputs, radialCount: radialCount)
                    }
                case .event(.radial):
                    radialCount += 1
                default:
                    break
                }
            }
            throw StreamTestFailure.timeout
        }
        group.addTask {
            try await Task.sleep(for: .seconds(2))
            throw StreamTestFailure.timeout
        }
        guard let result = try await group.next() else { throw StreamTestFailure.timeout }
        group.cancelAll()
        return result
    }
}

private func waitForStreamTestWrite(on transport: SimulatedMicroTransport) async throws {
    for _ in 0..<200 {
        if !(await transport.capturedWrites()).isEmpty { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw StreamTestFailure.timeout
}

private func waitForStreamTestConnection(
    _ coordinator: MicroDeviceCoordinator
) async throws {
    for _ in 0..<200 {
        if case .connected = await coordinator.connectionState { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw StreamTestFailure.timeout
}

private func streamTestStatusPayload() -> Data {
    Data(#"{"result":{"version":"test","layer_index":0},"id":1}"#.utf8)
}

private func streamTestInputPayload(control: String, activity: Int) -> Data {
    Data("{\"m\":\"v.oai.hid\",\"p\":{\"k\":\"\(control)\",\"act\":\(activity)}}".utf8)
}

private func streamTestRadialPayload(index: Int) -> Data {
    let angle = Double(index % 100) / 100
    return Data("{\"m\":\"v.oai.rad\",\"p\":{\"a\":\(angle),\"d\":1}}".utf8)
}

private enum StreamTestFailure: Error {
    case timeout
}
