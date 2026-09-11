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
        case method = "m"
        case params = "p"
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
        case method = "m"
        case params = "p"
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
