import CreatorMicroCore
import Foundation

actor LocalProcessSessionAdapter: AgentSessionAdapter {
    nonisolated let source = AgentSource.localProcess
    nonisolated let focusCapabilities: Set<AgentFocusCapability> = [.process]

    private let parser: AgentProcessEvidenceParser
    private let focusController: any AgentFocusControlling

    init(
        executableNames: Set<String>,
        focusController: any AgentFocusControlling
    ) {
        self.parser = AgentProcessEvidenceParser(executableNames: executableNames)
        self.focusController = focusController
    }

    func fetchSessions() async throws -> [AgentSession] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,state=,comm="]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AgentSessionAdapterError.fetchFailed
        }
        return parser.parse(data, observedAt: Date()).sessions
    }

    func focus(_ target: AgentFocusTarget) async throws {
        try await focusController.focus(target)
    }
}
