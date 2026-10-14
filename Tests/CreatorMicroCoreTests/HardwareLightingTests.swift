import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroLightingPayloadTests: XCTestCase {
    func testAgentStatusRequiresAndEncodesAllSixLightsInPhysicalOrder() throws {
        let lights = try [5, 1, 4, 0, 3, 2].map { index in
            try AgentKeyLighting(
                index: index,
                color: RGBColor(red: UInt8(index), green: 0x80, blue: 0xFF),
                brightness: 0.75,
                effect: .solid,
                speed: 0.25
            )
        }

        let payload = try LightingPayloadBuilder.agentStatus(lights)
        let decoded = try JSONDecoder().decode(AgentStatusMessage.self, from: payload)

        XCTAssertEqual(decoded.method, "v.oai.thstatus")
        XCTAssertEqual(decoded.params.map(\.identifier), Array(0..<6))
        XCTAssertEqual(decoded.params[2].color, 0x0280FF)
        XCTAssertNil(decoded.identifier)
    }

    func testAgentStatusRejectsMissingAndDuplicateLights() throws {
        let light = try AgentKeyLighting(index: 0, color: .green)

        XCTAssertThrowsError(try LightingPayloadBuilder.agentStatus([light]))
        XCTAssertThrowsError(
            try LightingPayloadBuilder.agentStatus(Array(repeating: light, count: 6))
        )
    }

    func testLightingValidationRejectsInvalidIndexAndUnitValues() {
        XCTAssertThrowsError(try AgentKeyLighting(index: 6, color: .red))
        XCTAssertThrowsError(
            try AgentKeyLighting(index: 0, color: .red, brightness: 1.1)
        )
    }

    func testCapabilityAwareKeyStatusAddressesAllThirteenCreatorPositions() throws {
        let capability = DeviceCapabilityProfile(productIdentifier: 0x8298)
        let lights = try (0..<13).map { index in
            try AgentKeyLighting(index: index, color: .green, validIndices: 0..<13)
        }

        let payload = try LightingPayloadBuilder.keyStatus(lights, capability: capability)
        let decoded = try JSONDecoder().decode(AgentStatusMessage.self, from: payload)

        XCTAssertEqual(decoded.method, "v.oai.thstatus")
        XCTAssertEqual(decoded.params.map(\.identifier), Array(0..<13))
    }

    func testCapabilityAwareKeyStatusRejectsCountMismatchedToCapability() throws {
        let codex = DeviceCapabilityProfile(productIdentifier: 0x8360)
        let thirteenLights = try (0..<13).map { index in
            try AgentKeyLighting(index: index, color: .green, validIndices: 0..<13)
        }

        XCTAssertThrowsError(try LightingPayloadBuilder.keyStatus(thirteenLights, capability: codex))
    }

    func testAgentKeyLightingRejectsIndexOutsideExplicitValidRange() {
        XCTAssertThrowsError(try AgentKeyLighting(index: 13, color: .red, validIndices: 0..<13))
    }

    func testCreatorPartialUpdateIncludesOnlyChangedKeys() throws {
        let creator = DeviceCapabilityProfile(productIdentifier: 0x8298)
        let lights = try [11, 10].map {
            try AgentKeyLighting(index: $0, color: .red, validIndices: 0..<13)
        }
        let payload = try LightingPayloadBuilder.keyStatusUpdates(lights, capability: creator)
        let decoded = try JSONDecoder().decode(AgentStatusMessage.self, from: payload)
        XCTAssertEqual(decoded.params.map(\.identifier), [10, 11])
    }

    func testPartialUpdateRejectsEmptyDuplicateOutOfRangeAndCodexSubsets() throws {
        let creator = DeviceCapabilityProfile(productIdentifier: 0x8298)
        let light = try AgentKeyLighting(index: 0, color: .red)
        let invalid = try AgentKeyLighting(index: 13, color: .red, validIndices: 0..<20)
        XCTAssertThrowsError(try LightingPayloadBuilder.keyStatusUpdates([], capability: creator))
        XCTAssertThrowsError(try LightingPayloadBuilder.keyStatusUpdates([light, light], capability: creator))
        XCTAssertThrowsError(try LightingPayloadBuilder.keyStatusUpdates([invalid], capability: creator))
        let codex = DeviceCapabilityProfile(productIdentifier: 0x8360)
        XCTAssertThrowsError(try LightingPayloadBuilder.keyStatusUpdates([light], capability: codex))
        let six = try (0..<6).map { try AgentKeyLighting(index: $0, color: .red) }
        XCTAssertNoThrow(try LightingPayloadBuilder.keyStatusUpdates(six, capability: codex))
    }

    func testRGBConfigurationRejectsEmptyZonesAndInvalidValues() {
        XCTAssertThrowsError(try LightingPayloadBuilder.rgbConfiguration(ambient: nil, keys: nil))
        XCTAssertThrowsError(try ZoneLighting(color: .green, brightness: .nan))
        XCTAssertThrowsError(try ZoneLighting(color: .green, speed: -0.1))
        XCTAssertNil(RGBColor(rawValue: -1))
        XCTAssertNil(RGBColor(rawValue: 0x1000000))
        XCTAssertEqual(RGBColor(rawValue: 0x00FF00), .green)
    }

    func testRGBConfigurationCanAddressOnlyKeyZone() throws {
        let payload = try LightingPayloadBuilder.rgbConfiguration(
            ambient: nil, keys: ZoneLighting(color: .blue))
        let decoded = try JSONDecoder().decode(RGBConfigurationMessage.self, from: payload)
        XCTAssertNil(decoded.params.ambient)
        XCTAssertEqual(decoded.params.keys?.color, 0x0000FF)
    }

    func testRGBConfigurationUsesMinimizedVendorFields() throws {
        let ambient = try ZoneLighting(
            color: RGBColor(red: 0x11, green: 0x22, blue: 0x33),
            brightness: 0.5,
            effect: .breath,
            speed: 0.2
        )

        let payload = try LightingPayloadBuilder.rgbConfiguration(
            ambient: ambient,
            keys: nil
        )
        let decoded = try JSONDecoder().decode(RGBConfigurationMessage.self, from: payload)

        XCTAssertEqual(decoded.method, "v.oai.rgbcfg")
        XCTAssertEqual(decoded.params.ambient?.color, 0x112233)
        XCTAssertNil(decoded.params.keys)
    }
}

private struct AgentStatusMessage: Decodable {
    let method: String
    let params: [AgentStatusEntry]
    let identifier: Int?

    enum CodingKeys: String, CodingKey {
        case method
        case params
        case identifier = "id"
    }
}

private struct AgentStatusEntry: Decodable {
    let identifier: Int
    let color: Int

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case color = "c"
    }
}

private struct RGBConfigurationMessage: Decodable {
    let method: String
    let params: RGBConfigurationParameters

    enum CodingKeys: String, CodingKey {
        case method
        case params
    }
}

private struct RGBConfigurationParameters: Decodable {
    let ambient: ZoneEntry?
    let keys: ZoneEntry?
}

private struct ZoneEntry: Decodable {
    let color: Int

    enum CodingKeys: String, CodingKey {
        case color = "c"
    }
}
