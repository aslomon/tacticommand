import CreatorMicroCore

extension CreatorActionExecutionFailure {
    var userMessage: String {
        switch self {
        case .event(let failure): failure.userMessage
        case .workspace(let failure): failure.userMessage
        case .audio(let failure): "Audio control failed: \(failure)"
        case .script(let failure): "Configured automation failed: \(failure)"
        case .shortcutRequired:
            "Record a shortcut for this dictation provider first."
        case .unsupportedDictationBehavior:
            "This dictation provider does not support hold to talk."
        case .unsupportedAction:
            "This action is not available in the current context."
        }
    }
}

extension SystemEventFailure {
    var userMessage: String {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility access is required for keyboard and pointer control."
        case .unsupportedKey(let key):
            "The configured key \(key) is not supported."
        case .tooManyShortcutKeys(let count):
            "The shortcut has \(count) keys; at most eight are supported."
        case .eventCreationFailed:
            "macOS could not create the requested input event."
        case .cancelled:
            "The input action was cancelled."
        }
    }
}

extension WorkspaceApplicationFailure {
    fileprivate var userMessage: String {
        switch self {
        case .applicationNotFound(let identifier):
            "Application not found: \(identifier)"
        case .activationFailed(let identifier):
            "Application could not be focused: \(identifier)"
        }
    }
}

extension AgentFocusUnavailableReason {
    var userMessage: String {
        switch self {
        case .emptySlot: "No live agent is assigned to this key."
        case .noFocusTarget: "This agent has no verified window to focus."
        case .adapterUnavailable: "The agent source is unavailable."
        case .unsupportedTarget: "This agent target cannot be focused yet."
        case .focusFailed: "The verified agent window could not be focused."
        }
    }
}
