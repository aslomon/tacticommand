import Foundation
import XCTest

@testable import CreatorMicroCore

final class AgentStatusTests: XCTestCase {
    func testFactoryDeviceLightsMatchTheCreatorMicroProtocol() {
        let expected: [AgentStatus: AgentDeviceLight] = [
            .idle: AgentDeviceLight(hex: "#FFFFFF", brightness: 1),
            .working: AgentDeviceLight(hex: "#304FFE", brightness: 1),
            .waiting: AgentDeviceLight(hex: "#FF6D00", brightness: 1),
            .complete: AgentDeviceLight(hex: "#00FF4C", brightness: 1),
            .error: AgentDeviceLight(hex: "#FF0033", brightness: 1),
            .unavailable: .off,
        ]

        for (status, light) in expected {
            XCTAssertEqual(status.deviceLight, light)
        }
    }

    func testAttentionAndPriorityRepresentActionableState() {
        XCTAssertTrue(AgentStatus.waiting.needsAttention)
        XCTAssertTrue(AgentStatus.error.needsAttention)
        XCTAssertTrue(AgentStatus.complete.needsAttention)
        XCTAssertFalse(AgentStatus.working.needsAttention)
        XCTAssertGreaterThan(AgentStatus.waiting.priority, AgentStatus.error.priority)
        XCTAssertGreaterThan(AgentStatus.error.priority, AgentStatus.complete.priority)
        XCTAssertGreaterThan(AgentStatus.complete.priority, AgentStatus.working.priority)
        XCTAssertGreaterThan(AgentStatus.idle.priority, AgentStatus.unavailable.priority)
    }

    func testUnknownStatusDecodesAsUnavailable() throws {
        let data = Data(#""future-provider-state""#.utf8)
        let decoded = try JSONDecoder().decode(AgentStatus.self, from: data)

        XCTAssertEqual(decoded, .unavailable)
    }
}
