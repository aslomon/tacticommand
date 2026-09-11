import Foundation

public struct AgentEvidenceContext: Equatable, Sendable {
    public let isLive: Bool
    public let observedAt: Date
    public let terminalBundleIdentifier: String

    public init(
        isLive: Bool,
        observedAt: Date,
        terminalBundleIdentifier: String
    ) {
        self.isLive = isLive
        self.observedAt = observedAt
        self.terminalBundleIdentifier = terminalBundleIdentifier
    }
}

public struct AgentEvidenceParseResult: Equatable, Sendable {
    public let session: AgentSession
    public let malformedLineCount: Int

    public init(session: AgentSession, malformedLineCount: Int) {
        self.session = session
        self.malformedLineCount = malformedLineCount
    }
}

public struct AgentProcessEvidenceParseResult: Equatable, Sendable {
    public let sessions: [AgentSession]
    public let malformedLineCount: Int

    public init(sessions: [AgentSession], malformedLineCount: Int) {
        self.sessions = sessions
        self.malformedLineCount = malformedLineCount
    }
}

public enum AgentEvidenceParserError: Error, Equatable, Sendable {
    case missingSessionIdentity
}

public protocol AgentSessionEvidenceParsing: Sendable {
    var source: AgentSource { get }

    func parse(
        _ data: Data,
        context: AgentEvidenceContext
    ) throws -> AgentEvidenceParseResult
}

struct DecodedJSONLines<Record: Decodable> {
    let records: [Record]
    let malformedLineCount: Int
}

func decodeJSONLines<Record: Decodable>(
    _ type: Record.Type,
    from data: Data
) -> DecodedJSONLines<Record> {
    var records: [Record] = []
    var malformedLineCount = 0
    let decoder = JSONDecoder()

    for line in data.split(separator: 0x0A) {
        do {
            records.append(try decoder.decode(type, from: Data(line)))
        } catch {
            malformedLineCount += 1
        }
    }
    return DecodedJSONLines(
        records: records,
        malformedLineCount: malformedLineCount
    )
}

func evidenceDate(_ value: String?, fallback: Date) -> Date {
    guard let value else { return fallback }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value) ?? fallback
}

func evidenceTitle(preferred: String?, workingDirectory: String?, fallback: String) -> String {
    if let preferred, !preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return preferred
    }
    if let workingDirectory, !workingDirectory.isEmpty {
        let name = URL(fileURLWithPath: workingDirectory).lastPathComponent
        if !name.isEmpty { return name }
    }
    return fallback
}

func terminalFocusTarget(
    bundleIdentifier: String,
    workingDirectory: String?
) -> AgentFocusTarget? {
    guard !bundleIdentifier.isEmpty else { return nil }
    return .terminal(
        bundleIdentifier: bundleIdentifier,
        workingDirectory: workingDirectory
    )
}

func statusWithLiveness(_ status: AgentStatus, isLive: Bool) -> AgentStatus {
    switch status {
    case .working, .waiting, .idle:
        isLive ? status : .unavailable
    case .complete, .error, .unavailable:
        status
    }
}
