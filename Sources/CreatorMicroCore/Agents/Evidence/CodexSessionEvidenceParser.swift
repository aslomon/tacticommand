import Foundation

public struct CodexSessionEvidenceParser: AgentSessionEvidenceParsing {
    public let source = AgentSource.codexAppServer

    public init() {}

    public func parse(
        _ data: Data,
        context: AgentEvidenceContext
    ) throws -> AgentEvidenceParseResult {
        let decoded = decodeJSONLines(CodexRecord.self, from: data)
        var identity: CodexIdentity?
        var latestStatus: AgentStatus?
        var updatedAt = context.observedAt

        for record in decoded.records {
            updatedAt = evidenceDate(record.timestamp, fallback: updatedAt)
            if record.type == "session_meta", let payload = record.payload {
                identity = CodexIdentity(payload: payload)
            }
            if let nextStatus = status(for: record) {
                latestStatus = nextStatus
            }
        }

        guard let identity, !identity.id.isEmpty else {
            throw AgentEvidenceParserError.missingSessionIdentity
        }
        return AgentEvidenceParseResult(
            session: makeSession(
                identity: identity,
                status: latestStatus ?? .idle,
                updatedAt: updatedAt,
                context: context
            ),
            malformedLineCount: decoded.malformedLineCount
        )
    }

    private func makeSession(
        identity: CodexIdentity,
        status: AgentStatus,
        updatedAt: Date,
        context: AgentEvidenceContext
    ) -> AgentSession {
        AgentSession(
            id: AgentSessionID(source: .codexAppServer, externalID: identity.id),
            title: evidenceTitle(
                preferred: identity.agentNickname,
                workingDirectory: identity.workingDirectory,
                fallback: "Codex"
            ),
            detail: identity.workingDirectory,
            status: statusWithLiveness(status, isLive: context.isLive),
            updatedAt: updatedAt,
            focusTarget: terminalFocusTarget(
                bundleIdentifier: context.terminalBundleIdentifier,
                workingDirectory: identity.workingDirectory
            )
        )
    }

    private func status(for record: CodexRecord) -> AgentStatus? {
        guard let payload = record.payload else { return nil }
        if record.type == "event_msg" {
            switch payload.type {
            case "task_started": return .working
            case "task_complete": return .complete
            case "error": return .error
            default: return nil
            }
        }
        guard record.type == "response_item" else { return nil }
        switch payload.type {
        case "function_call", "custom_tool_call":
            return waitingToolNames.contains(payload.name ?? "") ? .waiting : nil
        case "function_call_output", "custom_tool_call_output":
            return .working
        default:
            return nil
        }
    }

    private var waitingToolNames: Set<String> {
        ["request_user_input", "request_permissions", "request_approval"]
    }
}

private struct CodexIdentity {
    let id: String
    let workingDirectory: String?
    let agentNickname: String?

    init(payload: CodexRecord.Payload) {
        id = payload.id ?? payload.sessionID ?? ""
        workingDirectory = payload.workingDirectory
        agentNickname = payload.agentNickname
    }
}

private struct CodexRecord: Decodable {
    let timestamp: String?
    let type: String
    let payload: Payload?

    struct Payload: Decodable {
        let id: String?
        let sessionID: String?
        let workingDirectory: String?
        let agentNickname: String?
        let type: String?
        let name: String?

        enum CodingKeys: String, CodingKey {
            case id
            case sessionID = "session_id"
            case workingDirectory = "cwd"
            case agentNickname = "agent_nickname"
            case type
            case name
        }
    }
}
