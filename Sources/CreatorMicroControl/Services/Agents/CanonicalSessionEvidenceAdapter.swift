import CreatorMicroCore
import Foundation

actor CanonicalSessionEvidenceAdapter<Parser: AgentSessionEvidenceParsing>:
    AgentSessionAdapter
{
    nonisolated let source: AgentSource
    nonisolated let focusCapabilities: Set<AgentFocusCapability> = [
        .application,
        .window,
        .terminal,
        .process,
    ]

    private let root: URL
    private let maximumDepth: Int
    private let maximumCount: Int
    private let maximumAge: TimeInterval
    private let terminalBundleIdentifier: String
    private let parser: Parser
    private let focusController: any AgentFocusControlling
    private let fileScanner = RecentAgentEvidenceFileScanner()
    private let openFileScanner = OpenAgentEvidenceScanner()
    private let reader = BoundedAgentEvidenceReader()

    init(
        root: URL,
        maximumDepth: Int,
        maximumCount: Int,
        maximumAge: TimeInterval,
        terminalBundleIdentifier: String,
        parser: Parser,
        focusController: any AgentFocusControlling
    ) {
        self.root = root
        self.maximumDepth = maximumDepth
        self.maximumCount = maximumCount
        self.maximumAge = maximumAge
        self.terminalBundleIdentifier = terminalBundleIdentifier
        self.parser = parser
        self.focusController = focusController
        self.source = parser.source
    }

    func fetchSessions() async throws -> [AgentSession] {
        let observedAt = Date()
        let scan = try fileScanner.scan(
            root: root,
            newerThan: observedAt.addingTimeInterval(-maximumAge),
            maximumDepth: maximumDepth,
            maximumCount: maximumCount
        )
        let openFiles = openFileScanner.scan(scan.files)
        var sessions: [AgentSession] = []
        var failedFiles = 0

        for file in scan.files {
            do {
                let data = try reader.read(file.url)
                let path = file.url.standardizedFileURL.path
                let context = AgentEvidenceContext(
                    isLive: openFiles.isReliable
                        && openFiles.paths.contains(path),
                    observedAt: file.modificationDate,
                    terminalBundleIdentifier: terminalBundleIdentifier
                )
                sessions.append(try parser.parse(data, context: context).session)
            } catch {
                failedFiles += 1
            }
        }

        if sessions.isEmpty && (failedFiles > 0 || scan.hadUnreadableEntries) {
            throw AgentSessionAdapterError.invalidPayload
        }
        return sessions
    }

    func focus(_ target: AgentFocusTarget) async throws {
        try await focusController.focus(target)
    }
}

typealias CodexSessionEvidenceAdapter =
    CanonicalSessionEvidenceAdapter<CodexSessionEvidenceParser>
typealias ClaudeSessionEvidenceAdapter =
    CanonicalSessionEvidenceAdapter<ClaudeSessionEvidenceParser>
