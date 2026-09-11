import Foundation
import XCTest

@testable import CreatorMicroCore

final class AgentEvidenceParserTests: XCTestCase {
    func testCodexParserUsesCanonicalLifecycleAndTerminalFocus() throws {
        let data = try fixture(named: "codex-working.jsonl")
        let context = AgentEvidenceContext(
            isLive: true,
            observedAt: date("2026-09-10T14:00:00Z"),
            terminalBundleIdentifier: "com.apple.Terminal"
        )

        let result = try CodexSessionEvidenceParser().parse(data, context: context)

        XCTAssertEqual(result.session.id.externalID, "codex-thread-1")
        XCTAssertEqual(result.session.title, "Builder")
        XCTAssertEqual(result.session.status, .working)
        XCTAssertEqual(
            result.session.focusTarget,
            .terminal(
                bundleIdentifier: "com.apple.Terminal",
                workingDirectory: "/Users/example/Projects/control"
            )
        )
        XCTAssertEqual(result.malformedLineCount, 1)
    }

    func testCodexActiveClaimBecomesUnavailableWithoutLivenessProof() throws {
        let data = try fixture(named: "codex-working.jsonl")
        let context = AgentEvidenceContext(
            isLive: false,
            observedAt: date("2026-09-10T14:00:00Z"),
            terminalBundleIdentifier: "com.apple.Terminal"
        )

        let result = try CodexSessionEvidenceParser().parse(data, context: context)

        XCTAssertEqual(result.session.status, .unavailable)
    }

    func testCodexCompletionRemainsVisibleAfterWriterCloses() throws {
        let data = try fixture(named: "codex-complete.jsonl")
        let context = AgentEvidenceContext(
            isLive: false,
            observedAt: date("2026-09-10T14:00:00Z"),
            terminalBundleIdentifier: "com.apple.Terminal"
        )

        let result = try CodexSessionEvidenceParser().parse(data, context: context)

        XCTAssertEqual(result.session.status, .complete)
    }

    func testClaudeAskUserQuestionMapsToWaitingOnlyWhileLive() throws {
        let data = try fixture(named: "claude-waiting.jsonl")
        let parser = ClaudeSessionEvidenceParser()
        let liveContext = AgentEvidenceContext(
            isLive: true,
            observedAt: date("2026-09-10T14:00:00Z"),
            terminalBundleIdentifier: "com.apple.Terminal"
        )
        let staleContext = AgentEvidenceContext(
            isLive: false,
            observedAt: date("2026-09-10T14:00:00Z"),
            terminalBundleIdentifier: "com.apple.Terminal"
        )

        let live = try parser.parse(data, context: liveContext)
        let stale = try parser.parse(data, context: staleContext)

        XCTAssertEqual(live.session.title, "Release check")
        XCTAssertEqual(live.session.status, .waiting)
        XCTAssertEqual(stale.session.status, .unavailable)
        XCTAssertEqual(live.malformedLineCount, 0)
    }

    func testClaudeEndTurnMapsToComplete() throws {
        let data = try fixture(named: "claude-complete.jsonl")
        let context = AgentEvidenceContext(
            isLive: false,
            observedAt: date("2026-09-10T14:00:00Z"),
            terminalBundleIdentifier: "com.apple.Terminal"
        )

        let result = try ClaudeSessionEvidenceParser().parse(data, context: context)

        XCTAssertEqual(result.session.id.externalID, "claude-session-1")
        XCTAssertEqual(result.session.status, .complete)
    }

    func testProcessParserDoesNotInventActivityForConfiguredExecutables() throws {
        let data = try fixture(named: "processes.txt")
        let parser = AgentProcessEvidenceParser(
            executableNames: ["aider", "opencode"]
        )

        let result = parser.parse(
            data,
            observedAt: date("2026-09-10T14:00:00Z")
        )

        XCTAssertEqual(
            result.sessions.map(\.id.externalID),
            ["process-101", "process-303"]
        )
        XCTAssertTrue(result.sessions.allSatisfy { $0.status == .unavailable })
        XCTAssertTrue(
            result.sessions.allSatisfy {
                $0.detail?.contains("Activity unknown") == true
            }
        )
        XCTAssertEqual(
            result.sessions.first?.focusTarget,
            .process(processIdentifier: 101)
        )
        XCTAssertEqual(result.malformedLineCount, 1)
    }

    func testOpenFileEvidenceParserReturnsOnlyAbsoluteFileNames() throws {
        let data = try fixture(named: "open-files.txt")

        let result = OpenFileEvidenceParser().parse(data)

        XCTAssertEqual(
            result.paths,
            [
                "/Users/example/.claude/projects/session.jsonl",
                "/Users/example/.codex/sessions/session.jsonl",
            ]
        )
        XCTAssertEqual(result.malformedLineCount, 1)
    }
}

private func fixture(named name: String) throws -> Data {
    let fixtureURL = try XCTUnwrap(
        Bundle.module.url(
            forResource: name,
            withExtension: nil
        )
    )
    return try Data(contentsOf: fixtureURL)
}

private func date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value) ?? .distantPast
}
