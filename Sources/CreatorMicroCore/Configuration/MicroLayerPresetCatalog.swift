public enum MicroLayerPresetID: String, CaseIterable, Codable, Hashable, Sendable {
    case desktop
    case claudeCodeCLI
    case claudeApp
    case codexCLI
    case codexApp
    case cursor
    case meetings
    case agentFocus
    case browser
    case windowManagement
    case writing
    case snippets
}

public struct MicroLayerPreset: Identifiable, Equatable, Sendable {
    public let id: MicroLayerPresetID
    public let name: String
    public let detail: String
    private let overrides: [ControlID: CreatorAction]

    init(
        id: MicroLayerPresetID,
        name: String,
        detail: String,
        overrides: [ControlID: CreatorAction]
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.overrides = overrides
    }

    public func layer(
        for target: LayerIndex,
        desktopChassis: LayerConfiguration
    ) -> LayerConfiguration {
        var bindings = desktopChassis.bindings
        bindings[.action11] = .inputMute(.toggle)
        for control in Self.agentControls {
            bindings.removeValue(forKey: control)
        }
        for (control, action) in overrides {
            if action == .none {
                bindings.removeValue(forKey: control)
            } else {
                bindings[control] = action
            }
        }
        return LayerConfiguration(
            id: target,
            name: name,
            bindings: bindings,
            joystick: desktopChassis.joystick
        )
    }

    private static let agentControls: [ControlID] = [
        .agent0, .agent1, .agent2, .agent3, .agent4, .agent5,
    ]
}

public enum MicroLayerPresetCatalog {
    public static let defaultPresetOrder: [MicroLayerPresetID] = [
        .desktop,
        .claudeCodeCLI,
        .claudeApp,
        .codexCLI,
        .codexApp,
        .cursor,
        .meetings,
        .agentFocus,
        .windowManagement,
        .snippets,
    ]

    public static let all: [MicroLayerPreset] = [
        preset(
            .desktop,
            name: "Desktop",
            detail: "Everyday macOS navigation, pointer, clipboard, voice, and audio controls.",
            overrides: desktopOverrides
        ),
        preset(
            .claudeCodeCLI,
            name: "Claude Code CLI",
            detail:
                "Official Claude Code terminal controls for interruption, modes, transcript, status, context, and tasks.",
            overrides: claudeCodeCLIOverrides
        ),
        preset(
            .claudeApp,
            name: "Claude App",
            detail: "Safe desktop-app navigation, search, and clipboard shortcuts for Claude.",
            overrides: claudeAppOverrides
        ),
        preset(
            .codexCLI,
            name: "Codex CLI",
            detail: "Codex terminal commands for status, changes, review, projects, worktrees, and compaction.",
            overrides: codexCLIOverrides
        ),
        preset(
            .codexApp,
            name: "Codex App",
            detail: "Codex desktop-app shortcuts plus project and worktree navigation commands.",
            overrides: codexAppOverrides
        ),
        preset(
            .cursor,
            name: "Cursor",
            detail: "Layout-safe Cursor editor, clipboard, submit, and cancel controls.",
            overrides: cursorOverrides
        ),
        preset(
            .meetings,
            name: "Meetings",
            detail: "Universal microphone and output mute controls for calls and meetings.",
            overrides: meetingsOverrides
        ),
        preset(
            .agentFocus,
            name: "Agent Focus",
            detail: "Direct focus controls for six configured agent sessions.",
            overrides: agentFocusOverrides
        ),
        preset(
            .browser,
            name: "Browser",
            detail: "Address bar, tabs, reload, and find shortcuts for common macOS browsers.",
            overrides: browserOverrides
        ),
        preset(
            .windowManagement,
            name: "Window Management",
            detail: "Application and window switching with a primary pointer click.",
            overrides: windowManagementOverrides
        ),
        preset(
            .writing,
            name: "Writing",
            detail: "Clipboard, selection, undo, and redo controls for writing workflows.",
            overrides: writingOverrides
        ),
        preset(
            .snippets,
            name: "Snippets",
            detail: "Reusable text prompts for continuing, testing, summarizing, fixing, reviewing, and shipping.",
            overrides: snippetsOverrides
        ),
    ]

    public static func preset(for id: MicroLayerPresetID) -> MicroLayerPreset {
        all.first { $0.id == id } ?? all[0]
    }

    static func defaultPresetID(for layerID: LayerIndex) -> MicroLayerPresetID? {
        guard let index = LayerIndex.all.firstIndex(of: layerID),
            defaultPresetOrder.indices.contains(index)
        else {
            return nil
        }
        return defaultPresetOrder[index]
    }

    private static let desktopOverrides: [ControlID: CreatorAction] = [
        .agent0: .inputMute(.toggle),
        .agent1: .pointer(.click(.primary)),
        .agent2: .escapeKey,
        .agent3: .switchApplication(.next),
        .agent4: .shortOrLongPress(shortPress: .copy, longPress: .paste),
        .agent5: .deleteKey,
    ]

    private static let claudeCodeCLIOverrides: [ControlID: CreatorAction] = [
        .agent0: .escapeKey,
        .agent1: shortcut("tab", [.shift], name: "Permission Mode"),
        .agent2: shortcut("o", [.control], name: "Transcript"),
        .agent3: command("/status"),
        .agent4: command("/context"),
        .agent5: command("/tasks"),
    ]

    private static let claudeAppOverrides: [ControlID: CreatorAction] = [
        .agent0: shortcut("n", [.command], name: "New Chat"),
        .agent1: shortcut("k", [.command], name: "Command Palette"),
        .agent2: .copy,
        .agent3: .paste,
        .agent4: shortcut("f", [.command], name: "Find"),
        .agent5: .escapeKey,
    ]

    private static let codexCLIOverrides: [ControlID: CreatorAction] = [
        .agent0: command("/status"),
        .agent1: command("/diff"),
        .agent2: command("/review"),
        .agent3: command("/project"),
        .agent4: command("/worktree"),
        .agent5: command("/compact"),
    ]

    private static let codexAppOverrides: [ControlID: CreatorAction] = [
        .agent0: shortcut("n", [.command], name: "New Chat"),
        .agent1: shortcut("k", [.command], name: "Command Palette"),
        .agent2: .openTerminal,
        .agent3: command("/project"),
        .agent4: command("/worktree"),
        .agent5: command("/side"),
    ]

    private static let cursorOverrides: [ControlID: CreatorAction] = [
        .agent0: shortcut("i", [.command], name: "Agent"),
        .agent1: shortcut("n", [.command], name: "New Chat"),
        .agent2: .copy,
        .agent3: .paste,
        .agent4: shortcut("return", [.control], name: "Submit"),
        .agent5: shortcut("delete", [.control, .shift], name: "Cancel Generation"),
    ]

    private static let meetingsOverrides: [ControlID: CreatorAction] = [
        .agent0: .inputMute(.toggle),
        .agent1: .outputMute(.toggle),
    ]

    private static let agentFocusOverrides: [ControlID: CreatorAction] = [
        .agent0: .agentFocus(sessionID: "slot-1"),
        .agent1: .agentFocus(sessionID: "slot-2"),
        .agent2: .agentFocus(sessionID: "slot-3"),
        .agent3: .agentFocus(sessionID: "slot-4"),
        .agent4: .agentFocus(sessionID: "slot-5"),
        .agent5: .agentFocus(sessionID: "slot-6"),
    ]

    private static let browserOverrides: [ControlID: CreatorAction] = [
        .agent0: shortcut("l", [.command], name: "Address Bar"),
        .agent1: shortcut("t", [.command], name: "New Tab"),
        .agent2: shortcut("w", [.command], name: "Close Tab"),
        .agent3: shortcut("t", [.command, .shift], name: "Reopen Tab"),
        .agent4: shortcut("r", [.command], name: "Reload"),
        .agent5: shortcut("f", [.command], name: "Find"),
    ]

    private static let windowManagementOverrides: [ControlID: CreatorAction] = [
        .agent0: .switchApplication(.next),
        .agent1: .pointer(.click(.primary)),
        .agent2: .switchWindow(.next),
        .agent3: .switchWindow(.previous),
        .agent4: .switchApplication(.previous),
    ]

    private static let writingOverrides: [ControlID: CreatorAction] = [
        .agent0: .copy,
        .agent1: .paste,
        .agent2: .pastePlainText,
        .agent3: shortcut("a", [.command], name: "Select All"),
        .agent4: shortcut("z", [.command], name: "Undo"),
        .agent5: shortcut("z", [.command, .shift], name: "Redo"),
    ]

    private static let snippetsOverrides: [ControlID: CreatorAction] = [
        .agent0: .textSnippet("Please continue."),
        .agent1: .textSnippet("Run the tests."),
        .agent2: .textSnippet("Summarize the current status."),
        .agent3: .textSnippet("Fix the root cause."),
        .agent4: .textSnippet("Review these changes."),
        .agent5: .textSnippet("Ship it."),
    ]

    private static func preset(
        _ id: MicroLayerPresetID,
        name: String,
        detail: String,
        overrides: [ControlID: CreatorAction]
    ) -> MicroLayerPreset {
        MicroLayerPreset(id: id, name: name, detail: detail, overrides: overrides)
    }

    private static func command(_ value: String) -> CreatorAction {
        .slashCommand(command: value, submit: true)
    }

    private static func shortcut(
        _ key: String,
        _ modifiers: [KeyboardModifier],
        name: String? = nil
    ) -> CreatorAction {
        .keyboardShortcut(
            KeyShortcut(key: key, modifiers: modifiers, displayName: name)
        )
    }
}
