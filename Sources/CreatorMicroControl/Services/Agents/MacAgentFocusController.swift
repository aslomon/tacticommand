import AppKit
import CreatorMicroCore
import Foundation

protocol AgentFocusControlling: Sendable {
    func focus(_ target: AgentFocusTarget) async throws
}

struct MacAgentFocusController: AgentFocusControlling {
    func focus(_ target: AgentFocusTarget) async throws {
        switch target {
        case .application(let bundleIdentifier):
            try await activate(bundleIdentifier: bundleIdentifier)
        case .window(let bundleIdentifier, let title):
            if let title, !title.isEmpty {
                try await raiseWindow(
                    bundleIdentifier: bundleIdentifier,
                    hint: title
                )
            } else {
                try await activate(bundleIdentifier: bundleIdentifier)
            }
        case .terminal(let bundleIdentifier, let workingDirectory):
            if let workingDirectory, !workingDirectory.isEmpty {
                try await raiseWindow(
                    bundleIdentifier: bundleIdentifier,
                    hint: workingDirectory
                )
            } else {
                try await activate(bundleIdentifier: bundleIdentifier)
            }
        case .process(let processIdentifier):
            try await activate(processIdentifier: processIdentifier)
        case .codexThread:
            throw AgentFocusError.unsupportedTarget
        }
    }

    @MainActor
    private func activate(bundleIdentifier: String) throws {
        guard
            let application = NSWorkspace.shared.runningApplications.first(
                where: { $0.bundleIdentifier == bundleIdentifier }
            )
        else {
            throw AgentFocusError.applicationNotRunning
        }
        guard application.activate() else {
            throw AgentFocusError.activationFailed
        }
    }

    @MainActor
    private func activate(processIdentifier: Int32) throws {
        guard
            let application = NSRunningApplication(
                processIdentifier: processIdentifier
            )
        else {
            throw AgentFocusError.applicationNotRunning
        }
        guard application.activate() else {
            throw AgentFocusError.activationFailed
        }
    }

    @MainActor
    private func raiseWindow(bundleIdentifier: String, hint: String) throws {
        let source = accessibilityScript(
            bundleIdentifier: bundleIdentifier,
            hint: hint
        )
        guard let script = NSAppleScript(source: source) else {
            throw AgentFocusError.accessibilityFailed
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        guard error == nil else {
            throw AgentFocusError.accessibilityFailed
        }
    }

    private func accessibilityScript(
        bundleIdentifier: String,
        hint: String
    ) -> String {
        let bundleLiteral = appleScriptLiteral(bundleIdentifier)
        let hintLiteral = appleScriptLiteral(hint)
        return """
            tell application "System Events"
                set targetBundle to \(bundleLiteral)
                set targetHint to \(hintLiteral)
                set matches to application processes whose bundle identifier is targetBundle
                if (count of matches) is 0 then error number 1001
                set targetProcess to first item of matches
                repeat with targetWindow in windows of targetProcess
                    if (name of targetWindow as text) contains targetHint then
                        set frontmost of targetProcess to true
                        perform action "AXRaise" of targetWindow
                        return
                    end if
                end repeat
                error number 1002
            end tell
            """
    }

    private func appleScriptLiteral(_ value: String) -> String {
        let escaped =
            value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }
}

enum AgentFocusError: Error {
    case unsupportedTarget
    case applicationNotRunning
    case activationFailed
    case accessibilityFailed
}
