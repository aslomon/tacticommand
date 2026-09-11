import Foundation

public enum AgentSource: String, CaseIterable, Codable, Hashable, Sendable {
    case codexAppServer
    case claudeHooks
    case localProcess
}

public struct AgentSessionID: Codable, Equatable, Hashable, Sendable {
    public let source: AgentSource
    public let externalID: String

    public init(source: AgentSource, externalID: String) {
        self.source = source
        self.externalID = externalID
    }
}

public enum AgentFocusCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case codexThread
    case application
    case window
    case terminal
    case process
}

public enum AgentFocusTarget: Codable, Equatable, Hashable, Sendable {
    case codexThread(threadID: String)
    case application(bundleIdentifier: String)
    case window(bundleIdentifier: String, title: String?)
    case terminal(bundleIdentifier: String, workingDirectory: String?)
    case process(processIdentifier: Int32)

    public var capability: AgentFocusCapability {
        switch self {
        case .codexThread: .codexThread
        case .application: .application
        case .window: .window
        case .terminal: .terminal
        case .process: .process
        }
    }
}

public struct AgentSession: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: AgentSessionID
    public let title: String
    public let detail: String?
    public let status: AgentStatus
    public let updatedAt: Date
    public let focusTarget: AgentFocusTarget?

    public init(
        id: AgentSessionID,
        title: String,
        detail: String?,
        status: AgentStatus,
        updatedAt: Date,
        focusTarget: AgentFocusTarget?
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.updatedAt = updatedAt
        self.focusTarget = focusTarget
    }

    public var source: AgentSource {
        id.source
    }

    public var canFocus: Bool {
        focusTarget != nil
    }
}

public enum AgentSlotID: Int, CaseIterable, Codable, Hashable, Sendable {
    case one = 0
    case two
    case three
    case four
    case five
    case six

    public var physicalKeyID: String {
        "AG0\(rawValue)"
    }
}

public struct AgentSlot: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: AgentSlotID
    public let session: AgentSession?

    public init(id: AgentSlotID, session: AgentSession?) {
        self.id = id
        self.session = session
    }

    public var status: AgentStatus {
        session?.status ?? .unavailable
    }

    public var deviceLight: AgentDeviceLight {
        status.deviceLight
    }
}
