import Foundation

public protocol AgentSessionAdapter: Sendable {
    var source: AgentSource { get }
    var focusCapabilities: Set<AgentFocusCapability> { get }

    func fetchSessions() async throws -> [AgentSession]
    func focus(_ target: AgentFocusTarget) async throws
}

public enum AgentAdapterIssue: String, Codable, Equatable, Hashable, Sendable {
    case notRefreshed
    case sourceUnavailable
    case fetchFailed
    case invalidPayload
}

public enum AgentSessionAdapterError: Error, Equatable, Sendable {
    case sourceUnavailable
    case invalidPayload
    case fetchFailed
}

public enum AgentAdapterAvailability: Codable, Equatable, Hashable, Sendable {
    case available
    case unavailable(AgentAdapterIssue)
}

public enum AgentFocusUnavailableReason: String, Codable, Equatable, Hashable, Sendable {
    case emptySlot
    case noFocusTarget
    case adapterUnavailable
    case unsupportedTarget
    case focusFailed
}

public enum AgentFocusResult: Codable, Equatable, Hashable, Sendable {
    case focused
    case unavailable(AgentFocusUnavailableReason)
}

extension AgentSessionAdapter {
    public var focusCapabilities: Set<AgentFocusCapability> { [] }

    public func focus(_ target: AgentFocusTarget) async throws {
        throw AgentSessionAdapterFallbackError.unsupportedFocusTarget
    }
}

private enum AgentSessionAdapterFallbackError: Error {
    case unsupportedFocusTarget
}
