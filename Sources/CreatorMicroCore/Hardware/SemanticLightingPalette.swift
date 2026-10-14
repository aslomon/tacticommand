import Foundation

/// Function groupings used for resting-state (no transient signal) key color, approved by
/// Jason. Not exhaustive of every `CreatorAction` case; actions with no clear category bucket
/// into the closest approved group rather than inventing a new one.
public enum FunctionCategory: Equatable, Sendable {
    case navigationLayer
    case textClipboard
    case appWindowLaunch
    case audio
    case volume
    case recording
    case scripts

    public static func classify(_ action: CreatorAction) -> FunctionCategory? {
        switch action {
        case .none:
            return nil
        case .layer, .focusNextAgent, .agentFocus:
            return .navigationLayer
        case .copy, .paste, .pastePlainText, .textSnippet, .slashCommand,
            .returnKey, .escapeKey, .deleteKey, .approval, .keyboardShortcut, .pointer:
            return .textClipboard
        case .openTerminal, .openFinder, .openApplication, .switchApplication, .switchWindow:
            return .appWindowLaunch
        case .outputMute, .inputMute:
            return .audio
        case .volume:
            return .volume
        case .dictation:
            return .recording
        case .appleScript, .shellCommand:
            return .scripts
        case .shortOrLongPress(let shortPress, _):
            return classify(shortPress)
        case .actionSequence(let actions):
            return actions.lazy.compactMap(classify).first
        }
    }
}

public enum AudioObservedTone: Equatable, Sendable {
    case muted
    case mixed
    case unmuted
}

/// Approved semantic lighting palette (Jason, Opus plan item 2). Fixed values; never
/// redesign creatively here.
public enum SemanticLightingPalette {
    public static let navigationLayer = RGBColor(red: 0x24, green: 0xC8, blue: 0xDB)
    public static let textClipboard = RGBColor(red: 255, green: 244, blue: 230)
    public static let appWindowLaunch = RGBColor(red: 0x34, green: 0x78, blue: 0xF6)
    public static let volume = navigationLayer
    public static let recording = RGBColor(red: 0x22, green: 0xD3, blue: 0xA7)
    public static let scripts = RGBColor(red: 0xFF, green: 0x9F, blue: 0x0A)

    public static let audioMuted = RGBColor(red: 0xFF, green: 0x45, blue: 0x3A)
    public static let audioAttention = RGBColor(red: 0xFF, green: 0x9F, blue: 0x0A)
    public static let audioUnmuted = RGBColor(red: 0x30, green: 0xD1, blue: 0x58)

    public static let idleBrightness = 0.325
    public static let activeBrightness = 0.85
    public static let pressBrightness = 1.0

    public static func color(for category: FunctionCategory) -> RGBColor {
        switch category {
        case .navigationLayer: navigationLayer
        case .textClipboard: textClipboard
        case .appWindowLaunch: appWindowLaunch
        case .audio: audioUnmuted
        case .volume: volume
        case .recording: recording
        case .scripts: scripts
        }
    }

    public static func audioObserved(_ tone: AudioObservedTone) -> RGBColor {
        switch tone {
        case .muted: audioMuted
        case .mixed: audioAttention
        case .unmuted: audioUnmuted
        }
    }
}
