public enum LocalAutomationBindingPolicy {
    public static func authorize(
        _ action: CreatorAction
    ) -> Result<Void, LocalAutomationError> {
        switch action {
        case .shortOrLongPress(let shortPress, let longPress):
            if case .failure(let error) = authorize(shortPress) {
                return .failure(error)
            }
            return authorize(longPress)
        case .actionSequence(let actions):
            for action in actions {
                if case .failure(let error) = authorize(action) {
                    return .failure(error)
                }
            }
            return .success(())
        case .shellCommand:
            return forbidden(.shellCommand)
        case .appleScript:
            return forbidden(.appleScript)
        case .none:
            return .failure(
                LocalAutomationError(
                    code: .bindingNotFound,
                    message: "The selected control has no binding."
                )
            )
        default:
            return .success(())
        }
    }

    public static func events(
        for action: CreatorAction
    ) -> Result<[RoutedCreatorAction], LocalAutomationError> {
        switch authorize(action) {
        case .failure(let error): return .failure(error)
        case .success: break
        }
        if case .shortOrLongPress(let shortPress, _) = action {
            return events(for: shortPress)
        }
        let press = RoutedCreatorAction(action: action, phase: .pressed)
        guard case .dictation(let binding) = action,
            binding.behavior == .holdToTalk
        else {
            return .success([press])
        }
        return .success([
            press,
            RoutedCreatorAction(action: action, phase: .released),
        ])
    }

    public static func kind(of action: CreatorAction) -> LocalAutomationActionKind {
        switch action {
        case .none: .none
        case .dictation: .dictation
        case .approval: .approval
        case .returnKey: .returnKey
        case .escapeKey: .escapeKey
        case .deleteKey: .deleteKey
        case .openTerminal: .openTerminal
        case .openFinder: .openFinder
        case .openApplication: .openApplication
        case .switchApplication: .switchApplication
        case .switchWindow: .switchWindow
        case .layer: .layer
        case .shortOrLongPress: .shortOrLongPress
        case .textSnippet: .textSnippet
        case .copy: .copy
        case .paste: .paste
        case .pastePlainText: .pastePlainText
        case .keyboardShortcut: .keyboardShortcut
        case .slashCommand: .slashCommand
        case .actionSequence: .actionSequence
        case .volume: .volume
        case .outputMute: .outputMute
        case .inputMute: .inputMute
        case .pointer: .pointer
        case .appleScript: .appleScript
        case .shellCommand: .shellCommand
        case .agentFocus: .agentFocus
        case .focusNextAgent: .focusNextAgent
        }
    }

    private static func forbidden(
        _ kind: LocalAutomationActionKind
    ) -> Result<Void, LocalAutomationError> {
        .failure(
            LocalAutomationError(
                code: .forbiddenAction,
                message: "The \(kind.rawValue) action is forbidden over local RPC.",
                actionKind: kind
            )
        )
    }
}
