import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

final class DeviceLightingFrameTests: XCTestCase {
    func testInitialAndModelChangedFramesReplayAllZonesAndKeys() throws {
        let creator = try frame(productIdentifier: 0x8298)
        XCTAssertEqual(try creator.payloads(comparedTo: nil).count, 3)
        let codex = try frame(productIdentifier: 0x8360)
        let replay = try codex.payloads(comparedTo: creator)
        XCTAssertEqual(replay.count, 3)
        XCTAssertEqual(try identifiers(in: XCTUnwrap(replay.last)), Array(0..<6))
    }

    func testUnchangedFrameIsSilent() throws {
        let state = try frame(productIdentifier: 0x8298)
        XCTAssertTrue(try state.payloads(comparedTo: state).isEmpty)
    }

    func testBothCreatorPIDsUseTheSameBoundedDeltaProtocol() throws {
        for pid in [0x8297, 0x8298] {
            let previous = try frame(productIdentifier: pid)
            var keys = previous.keys
            keys[0] = try AgentKeyLighting(index: 0, color: .red)
            let current = DeviceLightingFrame(
                ambient: previous.ambient, sharedKeys: previous.sharedKeys,
                keys: keys, capability: previous.capability)
            let updates = try current.payloads(comparedTo: previous)
            XCTAssertEqual(updates.count, 1)
            XCTAssertEqual(try identifiers(in: XCTUnwrap(updates.first)), [0])
        }
    }

    func testKeyOffDeltaKeepsTheExplicitOffStateAndPrecedesAmbient() throws {
        let previous = try frame(productIdentifier: 0x8298)
        var keys = previous.keys
        keys[0] = try AgentKeyLighting(index: 0, color: .black, brightness: 0, effect: .off)
        let current = DeviceLightingFrame(
            ambient: Data("changed ambient".utf8), sharedKeys: previous.sharedKeys,
            keys: keys, capability: previous.capability)
        let updates = try current.payloads(comparedTo: previous)
        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(try identifiers(in: XCTUnwrap(updates.first)), [0])
        let message = try JSONDecoder().decode(MicroJSONValue.self, from: XCTUnwrap(updates.first))
        let key = try XCTUnwrap(message["params"]?.array?.first)
        XCTAssertEqual(key["b"]?.integer, 0)
        XCTAssertEqual(key["c"]?.integer, 0)
        XCTAssertEqual(key["e"]?.integer, 0)
        XCTAssertEqual(updates.last, current.ambient)
    }

    func testZoneOnlyChangeDoesNotRewriteKeyThreads() throws {
        let previous = try frame(productIdentifier: 0x8298)
        let current = DeviceLightingFrame(
            ambient: Data("changed ambient".utf8), sharedKeys: Data("changed shared".utf8),
            keys: previous.keys, capability: previous.capability)
        XCTAssertEqual(try current.payloads(comparedTo: previous), [current.ambient, current.sharedKeys])
    }

    func testWideKeyDeltaIncludesBothLEDPositions() throws {
        let previous = try frame(productIdentifier: 0x8298)
        var keys = previous.keys
        for index in [10, 11] {
            keys[index] = try AgentKeyLighting(index: index, color: .red, validIndices: 0..<13)
        }
        let current = DeviceLightingFrame(
            ambient: previous.ambient, sharedKeys: previous.sharedKeys,
            keys: keys, capability: previous.capability)
        let updates = try current.payloads(comparedTo: previous)
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(try identifiers(in: XCTUnwrap(updates.first)), [10, 11])
    }

    private func frame(productIdentifier: Int) throws -> DeviceLightingFrame {
        let capability = DeviceCapabilityProfile(productIdentifier: productIdentifier)
        let keys = try (0..<capability.independentlyLitKeyCount).map {
            try AgentKeyLighting(index: $0, color: .green, validIndices: 0..<capability.independentlyLitKeyCount)
        }
        return DeviceLightingFrame(
            ambient: Data("ambient".utf8), sharedKeys: Data("shared".utf8), keys: keys, capability: capability)
    }

    private func identifiers(in payload: Data) throws -> [Int] {
        let message = try JSONDecoder().decode(MicroJSONValue.self, from: payload)
        return try XCTUnwrap(message["params"]?.array).compactMap { $0["id"]?.integer }
    }
}
