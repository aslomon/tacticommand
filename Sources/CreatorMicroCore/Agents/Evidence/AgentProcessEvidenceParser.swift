import Foundation

public struct AgentProcessEvidenceParser: Sendable {
    private let executableNames: Set<String>

    public init(executableNames: Set<String>) {
        self.executableNames = Set(executableNames.map { $0.lowercased() })
    }

    public func parse(
        _ data: Data,
        observedAt: Date
    ) -> AgentProcessEvidenceParseResult {
        guard let output = String(data: data, encoding: .utf8) else {
            return AgentProcessEvidenceParseResult(
                sessions: [],
                malformedLineCount: 1
            )
        }
        var sessions: [AgentSession] = []
        var malformedLineCount = 0
        for line in output.split(whereSeparator: \.isNewline) {
            guard let process = processEvidence(from: line) else {
                malformedLineCount += 1
                continue
            }
            guard executableNames.contains(process.executableName.lowercased()) else {
                continue
            }
            sessions.append(session(from: process, observedAt: observedAt))
        }
        return AgentProcessEvidenceParseResult(
            sessions: sessions.sorted { $0.id.externalID < $1.id.externalID },
            malformedLineCount: malformedLineCount
        )
    }

    private func processEvidence(from line: Substring) -> AgentProcessEvidence? {
        let fields = line.split(
            maxSplits: 3,
            omittingEmptySubsequences: true,
            whereSeparator: \.isWhitespace
        )
        guard
            fields.count == 4,
            let processIdentifier = Int32(fields[0]),
            Int32(fields[1]) != nil,
            !fields[2].hasPrefix("Z")
        else {
            return nil
        }
        let executablePath = String(fields[3])
        let executableName = URL(fileURLWithPath: executablePath).lastPathComponent
        guard !executableName.isEmpty else { return nil }
        return AgentProcessEvidence(
            processIdentifier: processIdentifier,
            executableName: executableName
        )
    }

    private func session(
        from process: AgentProcessEvidence,
        observedAt: Date
    ) -> AgentSession {
        AgentSession(
            id: AgentSessionID(
                source: .localProcess,
                externalID: "process-\(process.processIdentifier)"
            ),
            title: process.executableName,
            detail: "PID \(process.processIdentifier) · Activity unknown",
            status: .unavailable,
            updatedAt: observedAt,
            focusTarget: .process(processIdentifier: process.processIdentifier)
        )
    }
}

private struct AgentProcessEvidence {
    let processIdentifier: Int32
    let executableName: String
}
