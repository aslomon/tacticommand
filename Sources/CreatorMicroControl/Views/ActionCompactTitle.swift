import CreatorMicroCore

/// Abbreviated key-face titles, split out of `ActionPresentation.swift` to keep that file
/// under the 300-line limit. `actionTitle`/`ActionKind.title` remain the full-length text
/// used for tooltips and VoiceOver; these are purely the on-key presentation strings.
extension ActionKind {
    /// Abbreviated all-caps label that fits a 68 pt hardware key well at 9 pt type.
    /// `MicroKey` wraps this across up to two lines.
    var compactTitle: String {
        switch self {
        case .none: "NONE"
        case .dictation: "DICTATE"
        case .approval: "APPROVE"
        case .returnKey: "RETURN"
        case .escapeKey: "ESCAPE"
        case .deleteKey: "DELETE"
        case .terminal: "TERMINAL"
        case .finder: "FINDER"
        case .application: "OPEN APP"
        case .switchApplication: "SWITCH APP"
        case .switchWindow: "SWITCH WIN"
        case .nextLayer: "NEXT LAYER"
        case .previousLayer: "PREV LAYER"
        case .selectLayer: "SELECT LAYER"
        case .snippet: "TYPE TEXT"
        case .copy: "COPY"
        case .paste: "PASTE"
        case .pastePlainText: "PASTE PLAIN"
        case .keyboardShortcut: "SHORTCUT"
        case .slashCommand: "SLASH CMD"
        case .actionSequence: "SEQUENCE"
        case .volumeUp: "VOLUME UP"
        case .volumeDown: "VOLUME DOWN"
        case .volumeSet: "SET VOLUME"
        case .outputMute: "MUTE OUTPUT"
        case .inputMute: "MUTE MIC"
        case .pointerMove: "MOVE POINTER"
        case .primaryClick: "CLICK"
        case .secondaryClick: "RIGHT CLICK"
        case .middleClick: "MIDDLE CLICK"
        case .scrollUp: "SCROLL UP"
        case .scrollDown: "SCROLL DOWN"
        case .scrollLeft: "SCROLL LEFT"
        case .scrollRight: "SCROLL RIGHT"
        case .appleScript: "SCRIPT"
        case .shellCommand: "SHELL CMD"
        case .agentFocus: "FOCUS AGENT"
        case .focusNextAgent: "NEXT AGENT"
        }
    }
}

extension CreatorAction {
    /// Short label for the physical key face; see `ActionKind.compactTitle`.
    var compactActionTitle: String {
        if case .shortOrLongPress = self { return "SHORT/LONG" }
        if case .keyboardShortcut = self { return actionTitle }
        if case .slashCommand(let command, _) = self { return command.uppercased() }
        return ActionKind(action: self).compactTitle
    }
}
