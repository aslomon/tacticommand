import Foundation

public struct AgentSlotSnapshot: Codable, Equatable, Sendable {
    public let slots: [AgentSlot]
    public let adapterAvailability: [AgentSource: AgentAdapterAvailability]

    public init(
        slots: [AgentSlot],
        adapterAvailability: [AgentSource: AgentAdapterAvailability]
    ) {
        self.slots = slots
        self.adapterAvailability = adapterAvailability
    }

    public var sessions: [AgentSession] {
        slots.compactMap(\.session)
    }
}

public actor AgentSlotStore {
    public static let slotCount = AgentSlotID.allCases.count

    private let adapters: [AgentSource: any AgentSessionAdapter]
    private var sessionsBySource: [AgentSource: [AgentSession]] = [:]
    private var availability: [AgentSource: AgentAdapterAvailability]
    private var slots = AgentSlotID.allCases.map { AgentSlot(id: $0, session: nil) }

    public init(adapters: [any AgentSessionAdapter] = []) {
        var uniqueAdapters: [AgentSource: any AgentSessionAdapter] = [:]
        var initialAvailability: [AgentSource: AgentAdapterAvailability] = [:]
        for adapter in adapters where uniqueAdapters[adapter.source] == nil {
            uniqueAdapters[adapter.source] = adapter
            initialAvailability[adapter.source] = .unavailable(.notRefreshed)
        }
        self.adapters = uniqueAdapters
        self.availability = initialAvailability
    }

    public func snapshot() -> AgentSlotSnapshot {
        AgentSlotSnapshot(slots: slots, adapterAvailability: availability)
    }

    @discardableResult
    public func refresh() async -> AgentSlotSnapshot {
        for source in AgentSource.allCases {
            guard let adapter = adapters[source] else { continue }
            do {
                let sessions = try await adapter.fetchSessions()
                ingestValidated(sessions, from: source)
            } catch AgentSessionAdapterError.sourceUnavailable {
                markUnavailable(source, issue: .sourceUnavailable)
            } catch AgentSessionAdapterError.invalidPayload {
                markUnavailable(source, issue: .invalidPayload)
            } catch {
                markUnavailable(source, issue: .fetchFailed)
            }
        }
        return snapshot()
    }

    private func markUnavailable(_ source: AgentSource, issue: AgentAdapterIssue) {
        sessionsBySource[source] = []
        availability[source] = .unavailable(issue)
        rebuildSlots()
    }

    @discardableResult
    public func ingest(
        _ sessions: [AgentSession],
        from source: AgentSource
    ) -> AgentSlotSnapshot {
        ingestValidated(sessions, from: source)
        return snapshot()
    }

    public func focus(slot slotID: AgentSlotID) async -> AgentFocusResult {
        guard let session = slots.first(where: { $0.id == slotID })?.session else {
            return .unavailable(.emptySlot)
        }
        guard let target = session.focusTarget else {
            return .unavailable(.noFocusTarget)
        }
        guard let adapter = adapters[session.source] else {
            return .unavailable(.adapterUnavailable)
        }
        guard adapter.focusCapabilities.contains(target.capability) else {
            return .unavailable(.unsupportedTarget)
        }
        do {
            try await adapter.focus(target)
            return .focused
        } catch {
            return .unavailable(.focusFailed)
        }
    }

    private func ingestValidated(_ sessions: [AgentSession], from source: AgentSource) {
        guard sessions.allSatisfy({ $0.source == source }) else {
            sessionsBySource[source] = []
            availability[source] = .unavailable(.invalidPayload)
            rebuildSlots()
            return
        }
        sessionsBySource[source] = deduplicated(sessions)
        availability[source] = .available
        rebuildSlots()
    }

    private func deduplicated(_ sessions: [AgentSession]) -> [AgentSession] {
        var result: [AgentSessionID: AgentSession] = [:]
        for session in sessions {
            guard let current = result[session.id] else {
                result[session.id] = session
                continue
            }
            let isNewer = session.updatedAt > current.updatedAt
            let isHigherPriority = session.status.priority > current.status.priority
            if isNewer || (session.updatedAt == current.updatedAt && isHigherPriority) {
                result[session.id] = session
            }
        }
        return Array(result.values)
    }

    private func rebuildSlots() {
        let selected = Array(
            allSessions().sorted(by: isHigherPriority).prefix(Self.slotCount)
        )
        var remaining = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })
        var rebuilt: [AgentSlot] = []

        for slotID in AgentSlotID.allCases {
            let previousID = slots.first(where: { $0.id == slotID })?.session?.id
            if let previousID, let session = remaining.removeValue(forKey: previousID) {
                rebuilt.append(AgentSlot(id: slotID, session: session))
            } else {
                rebuilt.append(AgentSlot(id: slotID, session: nil))
            }
        }

        var unassigned = selected.filter { remaining[$0.id] != nil }
        for index in rebuilt.indices
        where rebuilt[index].session == nil && !unassigned.isEmpty {
            rebuilt[index] = AgentSlot(
                id: rebuilt[index].id,
                session: unassigned.removeFirst()
            )
        }
        slots = rebuilt
    }

    private func allSessions() -> [AgentSession] {
        sessionsBySource.values.flatMap { $0 }
    }

    private func isHigherPriority(_ left: AgentSession, _ right: AgentSession) -> Bool {
        if left.status.priority != right.status.priority {
            return left.status.priority > right.status.priority
        }
        if left.updatedAt != right.updatedAt {
            return left.updatedAt > right.updatedAt
        }
        if left.source.rawValue != right.source.rawValue {
            return left.source.rawValue < right.source.rawValue
        }
        return left.id.externalID < right.id.externalID
    }
}
