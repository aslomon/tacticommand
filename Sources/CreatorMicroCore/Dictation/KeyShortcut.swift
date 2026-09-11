import Foundation

public struct KeyShortcutKey: Codable, Hashable, Sendable {
    public let key: String
    public let virtualKeyCode: UInt16?

    public init(key: String, virtualKeyCode: UInt16? = nil) {
        self.key = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.virtualKeyCode = virtualKeyCode
    }

    public var representedModifier: KeyboardModifier? {
        switch key {
        case "fn", "function": .function
        case "ctrl", "control": .control
        case "opt", "option", "alt": .option
        case "shift": .shift
        case "cmd", "command": .command
        default: nil
        }
    }
}

public struct KeyShortcut: Codable, Hashable, Sendable {
    public static let maximumMainKeyCount = 8

    public let mainKeys: [KeyShortcutKey]
    public let modifiers: [KeyboardModifier]
    public let pressCount: Int
    public let interTapIntervalMilliseconds: Int

    public var key: String { mainKeys.first?.key ?? "" }
    public var virtualKeyCode: UInt16? { mainKeys.first?.virtualKeyCode }
    public var isEmpty: Bool { mainKeys.isEmpty && modifiers.isEmpty }

    public init(
        key: String,
        modifiers: [KeyboardModifier] = [],
        pressCount: Int = 1,
        interTapIntervalMilliseconds: Int = 120,
        virtualKeyCode: UInt16? = nil
    ) {
        self.init(
            mainKeys: [KeyShortcutKey(key: key, virtualKeyCode: virtualKeyCode)],
            modifiers: modifiers,
            pressCount: pressCount,
            interTapIntervalMilliseconds: interTapIntervalMilliseconds
        )
    }

    public init(
        mainKeys: [KeyShortcutKey],
        modifiers: [KeyboardModifier] = [],
        pressCount: Int = 1,
        interTapIntervalMilliseconds: Int = 120
    ) {
        self.mainKeys = Self.distinct(mainKeys)
        var requestedModifiers = Set(modifiers)
        for mainKey in self.mainKeys {
            if let representedModifier = mainKey.representedModifier {
                requestedModifiers.remove(representedModifier)
            }
        }
        self.modifiers = KeyboardModifier.allCases.filter(requestedModifiers.contains)
        self.pressCount = min(max(pressCount, 1), 4)
        self.interTapIntervalMilliseconds = min(
            max(interTapIntervalMilliseconds, 30),
            1_000
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modifiers =
            try container.decodeIfPresent(
                [KeyboardModifier].self,
                forKey: .modifiers
            ) ?? []
        let pressCount = try container.decodeIfPresent(Int.self, forKey: .pressCount) ?? 1
        let interval =
            try container.decodeIfPresent(
                Int.self,
                forKey: .interTapIntervalMilliseconds
            ) ?? 120
        if let mainKeys = try container.decodeIfPresent([KeyShortcutKey].self, forKey: .mainKeys) {
            self.init(
                mainKeys: mainKeys,
                modifiers: modifiers,
                pressCount: pressCount,
                interTapIntervalMilliseconds: interval
            )
            return
        }
        self.init(
            key: try container.decode(String.self, forKey: .key),
            modifiers: modifiers,
            pressCount: pressCount,
            interTapIntervalMilliseconds: interval,
            virtualKeyCode: try container.decodeIfPresent(UInt16.self, forKey: .virtualKeyCode)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mainKeys, forKey: .mainKeys)
        try container.encode(key, forKey: .key)
        try container.encode(modifiers, forKey: .modifiers)
        try container.encode(pressCount, forKey: .pressCount)
        try container.encode(interTapIntervalMilliseconds, forKey: .interTapIntervalMilliseconds)
        try container.encodeIfPresent(virtualKeyCode, forKey: .virtualKeyCode)
    }

    private static func distinct(_ keys: [KeyShortcutKey]) -> [KeyShortcutKey] {
        keys.reduce(into: []) { result, key in
            guard !key.key.isEmpty,
                !result.contains(where: { sameIdentity($0, key) })
            else {
                return
            }
            result.append(key)
        }
    }

    private static func sameIdentity(_ left: KeyShortcutKey, _ right: KeyShortcutKey) -> Bool {
        if let leftCode = left.virtualKeyCode, let rightCode = right.virtualKeyCode {
            return leftCode == rightCode
        }
        return left.key == right.key
    }

    private enum CodingKeys: String, CodingKey {
        case mainKeys
        case key
        case modifiers
        case pressCount
        case interTapIntervalMilliseconds
        case virtualKeyCode
    }
}
