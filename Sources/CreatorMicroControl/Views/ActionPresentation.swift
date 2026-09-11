import CreatorMicroCore
import SwiftUI

enum ActionKind: String, CaseIterable, Identifiable {
    case none
    case dictation
    case approval
    case returnKey
    case escapeKey
    case deleteKey
    case terminal
    case finder
    case application
    case switchApplication
    case switchWindow
    case nextLayer
    case previousLayer
    case selectLayer
    case snippet
    case copy
    case paste
    case pastePlainText
    case keyboardShortcut
    case slashCommand
    case actionSequence
    case volumeUp
    case volumeDown
    case volumeSet
    case outputMute
    case inputMute
    case pointerMove
    case primaryClick
    case secondaryClick
    case middleClick
    case scrollUp
    case scrollDown
    case scrollLeft
    case scrollRight
    case appleScript
    case shellCommand
    case agentFocus
    case focusNextAgent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Unassigned"
        case .dictation: "Dictation"
        case .approval: "Approve"
        case .returnKey: "Return"
        case .escapeKey: "Escape"
        case .deleteKey: "Delete"
        case .terminal: "Open Terminal"
        case .finder: "Open Finder"
        case .application: "Open Application"
        case .switchApplication: "Switch Application"
        case .switchWindow: "Switch Window"
        case .nextLayer: "Next Layer"
        case .previousLayer: "Previous Layer"
        case .selectLayer: "Select Layer…"
        case .snippet: "Type Text"
        case .copy: "Copy"
        case .paste: "Paste"
        case .pastePlainText: "Paste as Plain Text"
        case .keyboardShortcut: "Keyboard Shortcut"
        case .slashCommand: "Slash Command"
        case .actionSequence: "Action Sequence"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .volumeSet: "Set Volume"
        case .outputMute: "Mute Output"
        case .inputMute: "Mute Microphone"
        case .pointerMove: "Move Pointer"
        case .primaryClick: "Primary Click"
        case .secondaryClick: "Secondary Click"
        case .middleClick: "Middle Click"
        case .scrollUp: "Scroll Up"
        case .scrollDown: "Scroll Down"
        case .scrollLeft: "Scroll Left"
        case .scrollRight: "Scroll Right"
        case .appleScript: "AppleScript"
        case .shellCommand: "Shell Command"
        case .agentFocus: "Focus Agent"
        case .focusNextAgent: "Focus Next Agent Needing Attention"
        }
    }

    var symbol: String {
        switch self {
        case .none: "minus"
        case .dictation: "waveform"
        case .approval: "checkmark.circle"
        case .returnKey: "return"
        case .escapeKey: "escape"
        case .deleteKey: "delete.left"
        case .terminal: "terminal"
        case .finder: "folder"
        case .application: "app"
        case .switchApplication: "arrow.trianglehead.swap"
        case .switchWindow: "macwindow.on.rectangle"
        case .nextLayer: "square.3.layers.3d.top.filled"
        case .previousLayer: "square.3.layers.3d.bottom.filled"
        case .selectLayer: "square.3.layers.3d"
        case .snippet: "text.cursor"
        case .copy: "doc.on.doc"
        case .paste: "clipboard"
        case .pastePlainText: "clipboard.fill"
        case .keyboardShortcut: "keyboard.badge.ellipsis"
        case .slashCommand: "text.line.first.and.arrowtriangle.forward"
        case .actionSequence: "list.number"
        case .volumeUp: "speaker.plus"
        case .volumeDown: "speaker.minus"
        case .volumeSet: "speaker.wave.2"
        case .outputMute: "speaker.slash"
        case .inputMute: "mic.slash"
        case .pointerMove: "cursorarrow.motionlines"
        case .primaryClick: "cursorarrow.click"
        case .secondaryClick: "cursorarrow.click.2"
        case .middleClick: "computermouse"
        case .scrollUp: "arrow.up"
        case .scrollDown: "arrow.down"
        case .scrollLeft: "arrow.left"
        case .scrollRight: "arrow.right"
        case .appleScript: "applescript"
        case .shellCommand: "chevron.left.forwardslash.chevron.right"
        case .agentFocus: "cpu"
        case .focusNextAgent: "exclamationmark.bubble"
        }
    }

    init(action: CreatorAction) {
        switch action {
        case .none: self = .none
        case .dictation: self = .dictation
        case .approval: self = .approval
        case .returnKey: self = .returnKey
        case .escapeKey: self = .escapeKey
        case .deleteKey: self = .deleteKey
        case .openTerminal: self = .terminal
        case .openFinder: self = .finder
        case .openApplication: self = .application
        case .switchApplication: self = .switchApplication
        case .switchWindow: self = .switchWindow
        case .layer(let command): self = Self.layerKind(command)
        case .shortOrLongPress(let shortPress, _):
            self = ActionKind(action: shortPress)
        case .textSnippet: self = .snippet
        case .copy: self = .copy
        case .paste: self = .paste
        case .pastePlainText: self = .pastePlainText
        case .keyboardShortcut: self = .keyboardShortcut
        case .slashCommand: self = .slashCommand
        case .actionSequence: self = .actionSequence
        case .volume(let command): self = Self.volumeKind(command)
        case .outputMute: self = .outputMute
        case .inputMute: self = .inputMute
        case .pointer(let command): self = Self.pointerKind(command)
        case .appleScript: self = .appleScript
        case .shellCommand: self = .shellCommand
        case .agentFocus: self = .agentFocus
        case .focusNextAgent: self = .focusNextAgent
        }
    }

    func makeAction(current: CreatorAction) -> CreatorAction {
        switch self {
        case .none: .none
        case .dictation:
            .dictation(DictationBinding(providerID: .rede, behavior: .toggle))
        case .approval: .approval
        case .returnKey: .returnKey
        case .escapeKey: .escapeKey
        case .deleteKey: .deleteKey
        case .terminal: .openTerminal
        case .finder: .openFinder
        case .application: .openApplication(bundleIdentifier: "")
        case .switchApplication: .switchApplication(.next)
        case .switchWindow: .switchWindow(.next)
        case .nextLayer: .layer(.next)
        case .previousLayer: .layer(.previous)
        case .selectLayer:
            if case .layer(.select) = current { current } else { .layer(.select(.desktop)) }
        case .snippet: .textSnippet(associatedText(from: current))
        case .copy: .copy
        case .paste: .paste
        case .pastePlainText: .pastePlainText
        case .keyboardShortcut:
            if case .keyboardShortcut = current {
                current
            } else {
                .keyboardShortcut(KeyShortcut(key: "k", modifiers: [.command]))
            }
        case .slashCommand:
            if case .slashCommand = current {
                current
            } else {
                .slashCommand(command: "/", submit: false)
            }
        case .actionSequence:
            if case .actionSequence = current {
                current
            } else {
                .actionSequence([.copy, .pastePlainText])
            }
        case .volumeUp: .volume(.increase)
        case .volumeDown: .volume(.decrease)
        case .volumeSet:
            if case .volume(.set) = current { current } else { .volume(.set(0.5)) }
        case .outputMute: .outputMute(.toggle)
        case .inputMute: .inputMute(.toggle)
        case .pointerMove: .pointer(.move(horizontal: 24, vertical: 0))
        case .primaryClick: .pointer(.click(.primary))
        case .secondaryClick: .pointer(.click(.secondary))
        case .middleClick: .pointer(.click(.middle))
        case .scrollUp: .pointer(.scroll(.up))
        case .scrollDown: .pointer(.scroll(.down))
        case .scrollLeft: .pointer(.scroll(.left))
        case .scrollRight: .pointer(.scroll(.right))
        case .appleScript: .appleScript(associatedText(from: current))
        case .shellCommand: .shellCommand(associatedText(from: current))
        case .agentFocus: .agentFocus(sessionID: "slot-1")
        case .focusNextAgent: .focusNextAgent
        }
    }

    private func associatedText(from action: CreatorAction) -> String {
        switch action {
        case .textSnippet(let value),
            .slashCommand(let value, _),
            .appleScript(let value),
            .shellCommand(let value):
            value
        default: ""
        }
    }

    private static func pointerKind(_ command: PointerCommand) -> ActionKind {
        switch command {
        case .move: .pointerMove
        case .click(.primary): .primaryClick
        case .click(.secondary): .secondaryClick
        case .click(.middle): .middleClick
        case .scroll(.up): .scrollUp
        case .scroll(.down): .scrollDown
        case .scroll(.left): .scrollLeft
        case .scroll(.right): .scrollRight
        }
    }

    private static func volumeKind(_ command: VolumeCommand) -> ActionKind {
        switch command {
        case .increase: .volumeUp
        case .decrease: .volumeDown
        case .set: .volumeSet
        }
    }

    private static func layerKind(_ command: LayerCommand) -> ActionKind {
        switch command {
        case .next: .nextLayer
        case .previous: .previousLayer
        case .select: .selectLayer
        }
    }
}

extension CreatorAction {
    var actionTitle: String {
        if case .shortOrLongPress = self { return "Short / Long Press" }
        return ActionKind(action: self).title
    }

    var actionSymbol: String {
        if case .shortOrLongPress = self { return "hand.tap" }
        return ActionKind(action: self).symbol
    }
}
