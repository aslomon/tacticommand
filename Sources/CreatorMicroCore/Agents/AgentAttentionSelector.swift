public enum AgentAttentionSelector {
    public static func nextSlot(in snapshot: AgentSlotSnapshot) -> AgentSlotID? {
        for status in [AgentStatus.waiting, .error, .complete] {
            if let slot = snapshot.slots.first(where: { $0.status == status }) {
                return slot.id
            }
        }
        return nil
    }
}
