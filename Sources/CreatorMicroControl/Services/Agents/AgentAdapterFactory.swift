import AppKit
import CreatorMicroCore
import Foundation

@MainActor
enum AgentAdapterFactory {
    static func makeDefault() -> [any AgentSessionAdapter] {
        let focusController = MacAgentFocusController()
        let terminalBundleIdentifier = preferredTerminalBundleIdentifier() ?? ""
        let home = FileManager.default.homeDirectoryForCurrentUser
        let codex = CodexSessionEvidenceAdapter(
            root: home.appendingPathComponent(".codex/sessions", isDirectory: true),
            maximumDepth: 4,
            maximumCount: 18,
            maximumAge: 1_800,
            terminalBundleIdentifier: terminalBundleIdentifier,
            parser: CodexSessionEvidenceParser(),
            focusController: focusController
        )
        let claude = ClaudeSessionEvidenceAdapter(
            root: home.appendingPathComponent(".claude/projects", isDirectory: true),
            maximumDepth: 2,
            maximumCount: 18,
            maximumAge: 1_800,
            terminalBundleIdentifier: terminalBundleIdentifier,
            parser: ClaudeSessionEvidenceParser(),
            focusController: focusController
        )
        let localProcesses = LocalProcessSessionAdapter(
            executableNames: AgentAdapterDefaults.localAgentExecutables,
            focusController: focusController
        )
        return [codex, claude, localProcesses]
    }

    private static func preferredTerminalBundleIdentifier() -> String? {
        for candidate in AgentAdapterDefaults.terminalBundleIdentifiers {
            if NSWorkspace.shared.runningApplications.contains(
                where: { $0.bundleIdentifier == candidate }
            ) {
                return candidate
            }
        }
        return nil
    }
}

private enum AgentAdapterDefaults {
    static let terminalBundleIdentifiers = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
    ]

    static let localAgentExecutables: Set<String> = [
        "aider",
        "amp",
        "gemini",
        "opencode",
        "cursor-agent",
    ]
}
