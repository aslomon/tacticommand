public enum LocalAutomationSocketOwnership: Equatable, Sendable {
    case missing
    case currentUserSocket
    case unsafe
}

public enum LocalAutomationSocketProbe: Equatable, Sendable {
    case notNeeded
    case reachable
    case refused
    case indeterminate
}

public enum LocalAutomationSocketPathDecision: Equatable, Sendable {
    case create
    case removeStale
    case rejectOccupied
}

public enum LocalAutomationSocketPathPolicy {
    public static func decision(
        ownership: LocalAutomationSocketOwnership,
        probe: LocalAutomationSocketProbe
    ) -> LocalAutomationSocketPathDecision {
        switch (ownership, probe) {
        case (.missing, _): .create
        case (.currentUserSocket, .refused): .removeStale
        case (.currentUserSocket, .reachable),
            (.currentUserSocket, .indeterminate),
            (.currentUserSocket, .notNeeded),
            (.unsafe, _):
            .rejectOccupied
        }
    }
}
