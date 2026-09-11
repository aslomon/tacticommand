import XCTest

@testable import CreatorMicroCore

final class AgentAttentionSelectorTests: XCTestCase {
    func testWaitingAgentWinsBeforeErrorAndComplete() {
        let snapshot = AgentSlotSnapshot(
            slots: [
                slot(.one, status: .complete),
                slot(.two, status: .error),
                slot(.three, status: .waiting),
            ],
            adapterAvailability: [:]
        )

        XCTAssertEqual(AgentAttentionSelector.nextSlot(in: snapshot), .three)
    }

    func testSelectorReturnsNilWhenNoAgentNeedsAttention() {
        let snapshot = AgentSlotSnapshot(
            slots: [slot(.one, status: .working), slot(.two, status: .idle)],
            adapterAvailability: [:]
        )

        XCTAssertNil(AgentAttentionSelector.nextSlot(in: snapshot))
    }

    private func slot(_ id: AgentSlotID, status: AgentStatus) -> AgentSlot {
        AgentSlot(
            id: id,
            session: AgentSession(
                id: AgentSessionID(source: .localProcess, externalID: "\(id.rawValue)"),
                title: "Agent",
                detail: nil,
                status: status,
                updatedAt: .distantPast,
                focusTarget: .application(bundleIdentifier: "com.example.Agent")
            )
        )
    }
}
