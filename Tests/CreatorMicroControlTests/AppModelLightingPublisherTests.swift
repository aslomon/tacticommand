import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelLightingPublisherTests: XCTestCase {
    func testRepeatedEqualFramesWriteOnceAndStayIdle() async throws {
        let (model, transport) = try await connectedModel()
        for _ in 0..<100 { await model.synchronizeLighting() }
        await model.lightingTask?.value
        let initial = await transport.capturedWrites()
        var decoder = MicroFrameDecoder()
        let payloads = initial.flatMap { decoder.feed($0) }
        XCTAssertEqual(payloads.count, 3)
        for _ in 0..<100 { await model.synchronizeLighting() }
        await model.lightingTask?.value
        let repeated = await transport.capturedWrites()
        XCTAssertEqual(repeated, initial)
        XCTAssertNil(model.lightingTask)
        XCTAssertNil(model.feedbackTask)
        await model.shutdown()
    }

    func testLatestFrameWinsAndReconnectBoundaryReplaysFullState() async throws {
        let (model, transport) = try await connectedModel()
        for index in 0..<100 {
            model.configuration.assign(
                action: index == 99 ? .copy : .openTerminal,
                to: .action6, on: model.activeLayer)
            await model.synchronizeLighting()
        }
        await model.lightingTask?.value
        var decoder = MicroFrameDecoder()
        let payloads = await transport.capturedWrites().flatMap { decoder.feed($0) }
        let last = try JSONDecoder().decode(MicroJSONValue.self, from: XCTUnwrap(payloads.last))
        let light = last["params"]?.array?.first { $0["id"]?.integer == 6 }
        XCTAssertEqual(light?["c"]?.integer, SemanticLightingPalette.textClipboard.rawValue)
        XCTAssertLessThanOrEqual(payloads.count, 6)
        await transport.clearCapturedWrites()
        model.resetLightingBoundary()
        await model.synchronizeLighting()
        await model.lightingTask?.value
        let replay = await transport.capturedWrites()
        XCTAssertFalse(replay.isEmpty)
        await model.shutdown()
    }

    func testCreatorSingleKeyChangeDoesNotResendAllThirteenLEDs() async throws {
        let (model, transport) = try await connectedModel()
        await model.synchronizeLighting()
        await model.lightingTask?.value
        await transport.clearCapturedWrites()
        model.configuration.assign(action: .copy, to: .action6, on: model.activeLayer)
        await model.synchronizeLighting()
        await model.lightingTask?.value
        let reports = await transport.capturedWrites()
        var decoder = MicroFrameDecoder()
        let payloads = reports.flatMap { decoder.feed($0) }
        XCTAssertEqual(payloads.count, 1)
        let message = try JSONDecoder().decode(MicroJSONValue.self, from: XCTUnwrap(payloads.first))
        XCTAssertEqual(message["params"]?.array?.compactMap { $0["id"]?.integer }, [6])
        XCTAssertLessThanOrEqual(reports.count, 3)
        await transport.clearCapturedWrites()
        model.resetLightingBoundary()
        await model.synchronizeLighting()
        await model.lightingTask?.value
        var replayDecoder = MicroFrameDecoder()
        let replay = await transport.capturedWrites().flatMap { replayDecoder.feed($0) }
        let replayKeys = try JSONDecoder().decode(MicroJSONValue.self, from: XCTUnwrap(replay.last))
        XCTAssertEqual(replayKeys["params"]?.array?.count, 13)
        await model.shutdown()
    }

    func testCodexKeyChangeKeepsItsExistingSixKeyProtocol() async throws {
        let (model, transport) = try await connectedModel(productIdentifier: 0x8360)
        await model.synchronizeLighting()
        await model.lightingTask?.value
        await transport.clearCapturedWrites()
        model.configuration.assign(action: .openTerminal, to: .agent2, on: model.activeLayer)
        await model.synchronizeLighting()
        await model.lightingTask?.value
        var decoder = MicroFrameDecoder()
        let payloads = await transport.capturedWrites().flatMap { decoder.feed($0) }
        let message = try JSONDecoder().decode(MicroJSONValue.self, from: XCTUnwrap(payloads.last))
        XCTAssertEqual(message["params"]?.array?.count, 6)
        await model.shutdown()
    }

    private func connectedModel(productIdentifier: Int = 0x8298) async throws -> (AppModel, SimulatedMicroTransport) {
        let transport = SimulatedMicroTransport(productIdentifier: productIdentifier)
        let coordinator = MicroDeviceCoordinator(connector: LightingTestConnector(transport: transport))
        await coordinator.start()
        for _ in 0..<100 {
            if await !transport.capturedWrites().isEmpty { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        await transport.injectMessage(
            Data(
                #"{"id":1,"method":"device.status","result":{"version":"0.6.3","profile_index":0,"layer_index":2,"battery":95,"is_charging":false}}"#
                    .utf8))
        for _ in 0..<100 {
            if await coordinator.identitySnapshot != nil { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let model = AppModel(
            configurationStore: ConfigurationStore(
                fileURL:
                    FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent("configuration.json")),
            coordinator: coordinator)
        model.connectionState = await coordinator.connectionState
        model.deviceIdentity = await coordinator.identitySnapshot
        XCTAssertNotNil(model.deviceIdentity)
        await transport.clearCapturedWrites()
        return (model, transport)
    }
}

private struct LightingTestConnector: MicroTransportConnector {
    let transport: SimulatedMicroTransport
    func connect() async throws -> any MicroTransport { transport }
}
