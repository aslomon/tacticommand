public enum ShortcutRecordingInput: Equatable, Sendable {
    case keyDown(
        key: String?,
        virtualKeyCode: UInt16? = nil,
        modifiers: [KeyboardModifier],
        isRepeat: Bool
    )
    case keyUp
    case modifiersChanged
}

public enum ShortcutRecordingDecision: Equatable, Sendable {
    case keepRecording
    case captured(KeyShortcut)
    case cancelled
    case cleared
}

public struct ShortcutRecordingResponse: Equatable, Sendable {
    public let decision: ShortcutRecordingDecision
    public let suppressesEvent: Bool

    public init(
        decision: ShortcutRecordingDecision,
        suppressesEvent: Bool
    ) {
        self.decision = decision
        self.suppressesEvent = suppressesEvent
    }
}

public struct ShortcutRecordingReducer: Sendable {
    public init() {}

    public func handle(_ input: ShortcutRecordingInput) -> ShortcutRecordingResponse {
        let decision: ShortcutRecordingDecision
        switch input {
        case .keyUp, .modifiersChanged:
            decision = .keepRecording
        case .keyDown(let key, let virtualKeyCode, let modifiers, let isRepeat):
            decision = keyDownDecision(
                key: key,
                virtualKeyCode: virtualKeyCode,
                modifiers: modifiers,
                isRepeat: isRepeat
            )
        }
        return ShortcutRecordingResponse(
            decision: decision,
            suppressesEvent: true
        )
    }

    private func keyDownDecision(
        key: String?,
        virtualKeyCode: UInt16?,
        modifiers: [KeyboardModifier],
        isRepeat: Bool
    ) -> ShortcutRecordingDecision {
        guard !isRepeat, let key, !key.isEmpty else { return .keepRecording }
        switch key.lowercased() {
        case "escape": return .cancelled
        case "delete", "forward-delete", "backspace": return .cleared
        default:
            return .captured(
                KeyShortcut(
                    key: key,
                    modifiers: modifiers,
                    virtualKeyCode: virtualKeyCode
                )
            )
        }
    }
}

public struct KeyShortcutDisplayFormatter: Sendable {
    public init() {}

    public func string(for shortcut: KeyShortcut) -> String {
        let components =
            shortcut.modifiers.map(modifierLabel)
            + shortcut.mainKeys.map { keyLabel($0.key) }
        let base = components.joined(separator: " + ")
        return shortcut.pressCount > 1
            ? "\(base) x\(shortcut.pressCount)"
            : base
    }

    private func modifierLabel(_ modifier: KeyboardModifier) -> String {
        switch modifier {
        case .function: "fn"
        case .control: "ctrl"
        case .option: "opt"
        case .shift: "shift"
        case .command: "cmd"
        }
    }

    private func keyLabel(_ key: String) -> String {
        switch key {
        case "return", "enter": "Return"
        case "space": "Space"
        case "tab": "Tab"
        case "grave": "`"
        case "left": "Left"
        case "right": "Right"
        case "up": "Up"
        case "down": "Down"
        default: key.count == 1 ? key.uppercased() : key
        }
    }
}

public enum DictationTestGestureStep: Equatable, Sendable {
    case send(ButtonPhase)
    case wait(milliseconds: Int)
}

public struct DictationTestGesturePlanner: Sendable {
    public init() {}

    public func steps(for binding: DictationBinding) -> [DictationTestGestureStep] {
        switch binding.behavior {
        case .toggle:
            [.send(.pressed)]
        case .holdToTalk:
            [
                .send(.pressed),
                .wait(milliseconds: 700),
                .send(.released),
            ]
        }
    }
}
