import Foundation

public struct DictationProviderID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(applicationBundleIdentifier: String) {
        rawValue = "application.\(applicationBundleIdentifier)"
    }

    public static let rede = Self(rawValue: "builtin.rede")
    public static let chatGPTCodex = Self(rawValue: "builtin.chatgpt-codex")
    public static let appleDictation = Self(rawValue: "builtin.apple-dictation")
}

public enum DictationBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case holdToTalk
    case toggle
}

public enum DictationProviderScope: String, Codable, Hashable, Sendable {
    case systemWide
    case applicationOnly
}

public enum DictationProviderAvailability: String, Codable, Hashable, Sendable {
    case available
    case notInstalled
}

public enum KeyboardModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case function
    case control
    case option
    case shift
    case command
}

public struct DictationBinding: Codable, Hashable, Sendable {
    public let providerID: DictationProviderID
    public let behavior: DictationBehavior
    public let shortcut: KeyShortcut?

    public init(
        providerID: DictationProviderID,
        behavior: DictationBehavior,
        shortcut: KeyShortcut? = nil
    ) {
        self.providerID = providerID
        self.behavior = behavior
        self.shortcut = shortcut
    }
}

public enum BuiltInDictationProvider: String, Codable, CaseIterable, Hashable, Sendable {
    case rede
    case chatGPTCodex
    case appleDictation

    public var id: DictationProviderID {
        switch self {
        case .rede: .rede
        case .chatGPTCodex: .chatGPTCodex
        case .appleDictation: .appleDictation
        }
    }

    public var applicationBundleIdentifiers: [String] {
        switch self {
        case .rede: ["app.rede.mac"]
        case .chatGPTCodex: ["com.openai.codex", "com.openai.chat"]
        case .appleDictation: []
        }
    }

    public func definition(
        availability: DictationProviderAvailability
    ) -> DictationProviderDefinition {
        switch self {
        case .rede:
            builtInDefinition(name: "rede", scope: .systemWide, availability: availability)
        case .chatGPTCodex:
            builtInDefinition(
                name: "ChatGPT / Codex",
                scope: .applicationOnly,
                availability: availability,
                shortcut: KeyShortcut(key: "d", modifiers: [.control, .shift])
            )
        case .appleDictation:
            builtInDefinition(
                name: "Apple Dictation",
                scope: .systemWide,
                availability: availability,
                shortcut: KeyShortcut(key: "fn", pressCount: 2)
            )
        }
    }

    private func builtInDefinition(
        name: String,
        scope: DictationProviderScope,
        availability: DictationProviderAvailability,
        shortcut: KeyShortcut? = nil
    ) -> DictationProviderDefinition {
        DictationProviderDefinition(
            id: id,
            displayName: name,
            source: .builtIn(self),
            scope: scope,
            availability: availability,
            defaultBehavior: .toggle,
            defaultShortcut: shortcut,
            applicationBundleIdentifier: applicationBundleIdentifiers.first,
            applicationPath: nil
        )
    }
}

public enum DictationProviderSource: Codable, Hashable, Sendable {
    case builtIn(BuiltInDictationProvider)
    case installedApplication
}

public struct DictationProviderDefinition: Codable, Hashable, Sendable {
    public let id: DictationProviderID
    public let displayName: String
    public let source: DictationProviderSource
    public let scope: DictationProviderScope
    public let availability: DictationProviderAvailability
    public let defaultBehavior: DictationBehavior
    public let defaultShortcut: KeyShortcut?
    public let applicationBundleIdentifier: String?
    public let applicationPath: String?

    public init(
        id: DictationProviderID,
        displayName: String,
        source: DictationProviderSource,
        scope: DictationProviderScope,
        availability: DictationProviderAvailability,
        defaultBehavior: DictationBehavior,
        defaultShortcut: KeyShortcut?,
        applicationBundleIdentifier: String?,
        applicationPath: String?
    ) {
        self.id = id
        self.displayName = displayName
        self.source = source
        self.scope = scope
        self.availability = availability
        self.defaultBehavior = defaultBehavior
        self.defaultShortcut = defaultShortcut
        self.applicationBundleIdentifier = applicationBundleIdentifier
        self.applicationPath = applicationPath
    }

    public var supportedBehaviors: [DictationBehavior] {
        switch source {
        case .builtIn(.chatGPTCodex), .builtIn(.appleDictation): [.toggle]
        case .builtIn(.rede), .installedApplication: [.holdToTalk, .toggle]
        }
    }
}

public struct InstalledApplication: Codable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let displayName: String
    public let applicationPath: String

    public init(bundleIdentifier: String, displayName: String, applicationPath: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.applicationPath = applicationPath
    }
}

public enum InstalledApplicationCatalogFailure: Error, Codable, Equatable, Sendable {
    case discoveryFailed(String)
}

public protocol InstalledApplicationCatalog: Sendable {
    func installedApplications() async
        -> Result<[InstalledApplication], InstalledApplicationCatalogFailure>
}
