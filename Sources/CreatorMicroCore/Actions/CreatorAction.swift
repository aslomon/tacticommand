public enum AppSwitchDirection: String, Codable, Hashable, Sendable {
    case next
    case previous
}

public enum VolumeCommand: Codable, Hashable, Sendable {
    case increase
    case decrease
    case set(Double)
}

public enum MuteCommand: String, Codable, Hashable, Sendable {
    case toggle
    case mute
    case unmute
}

public enum PointerButton: String, Codable, Hashable, Sendable {
    case primary
    case secondary
    case middle
}

public enum ScrollDirection: String, Codable, Hashable, Sendable {
    case up
    case down
    case left
    case right
}

public enum PointerCommand: Codable, Hashable, Sendable {
    case move(horizontal: Int, vertical: Int)
    case click(PointerButton)
    case scroll(ScrollDirection)
}

public enum CreatorAction: Codable, Hashable, Sendable {
    case none
    case dictation(DictationBinding)
    case approval
    case returnKey
    case escapeKey
    case deleteKey
    case openTerminal
    case openFinder
    case openApplication(bundleIdentifier: String)
    case switchApplication(AppSwitchDirection)
    case switchWindow(AppSwitchDirection)
    case layer(LayerCommand)
    indirect case shortOrLongPress(
        shortPress: CreatorAction,
        longPress: CreatorAction
    )
    case textSnippet(String)
    case copy
    case paste
    case pastePlainText
    case keyboardShortcut(KeyShortcut)
    case slashCommand(command: String, submit: Bool)
    indirect case actionSequence([CreatorAction])
    case volume(VolumeCommand)
    case outputMute(MuteCommand)
    case inputMute(MuteCommand)
    case pointer(PointerCommand)
    case appleScript(String)
    case shellCommand(String)
    case agentFocus(sessionID: String)
    case focusNextAgent
}
