import CoreGraphics
import CreatorMicroCore
import Foundation

enum MacVirtualKeyMap {
    static func keyName(for keyCode: CGKeyCode) -> String? {
        canonicalNames[keyCode]
    }

    static func keyName(
        for keyCode: CGKeyCode,
        event: CGEvent
    ) -> String? {
        keyName(
            for: keyCode,
            layoutText: layoutText(from: event)
        )
    }

    static func keyName(
        for keyCode: CGKeyCode,
        layoutText: String?
    ) -> String? {
        if let semanticName = semanticNames[keyCode] {
            return semanticName
        }
        return normalizedLayoutText(layoutText) ?? canonicalNames[keyCode]
    }

    static func keyCode(for keyName: String) -> CGKeyCode? {
        let normalized = keyName.lowercased()
        return aliases[normalized]
            ?? canonicalNames.first { $0.value == normalized }?.key
    }

    static func keyCode(for shortcut: KeyShortcut) -> CGKeyCode? {
        shortcut.virtualKeyCode ?? keyCode(for: shortcut.key)
    }

    static func keyCode(for key: KeyShortcutKey) -> CGKeyCode? {
        key.virtualKeyCode ?? keyCode(for: key.key)
    }

    static func keyCode(for modifier: KeyboardModifier) -> CGKeyCode {
        modifierKeyCodes[modifier] ?? 63
    }

    static func keyCodeForCurrentLayout(
        for keyName: String
    ) -> CGKeyCode? {
        let source = CGEventSource(stateID: .hidSystemState)
        return keyCode(forCurrentLayoutKeyName: keyName) { keyCode in
            guard
                let event = CGEvent(
                    keyboardEventSource: source,
                    virtualKey: keyCode,
                    keyDown: true
                )
            else {
                return nil
            }
            return self.keyName(for: keyCode, event: event)
        }
    }

    static func keyCode(
        forCurrentLayoutKeyName keyName: String,
        layoutName: (CGKeyCode) -> String?
    ) -> CGKeyCode? {
        let normalized =
            keyName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard normalized.count == 1 else { return keyCode(for: normalized) }
        return canonicalNames.keys.sorted().first { keyCode in
            layoutName(keyCode)?.lowercased() == normalized
        } ?? keyCode(for: normalized)
    }

    static func modifiers(from flags: CGEventFlags) -> [KeyboardModifier] {
        KeyboardModifier.allCases.filter { modifier in
            guard let flag = modifierFlags[modifier] else { return false }
            return flags.contains(flag)
        }
    }

    static func flags(for modifiers: [KeyboardModifier]) -> CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { flags, modifier in
            flags.insert(modifierFlags[modifier] ?? [])
        }
    }

    static func flags(
        for shortcut: KeyShortcut,
        phase: ButtonPhase
    ) -> CGEventFlags {
        guard let key = shortcut.mainKeys.first else {
            return flags(for: shortcut.modifiers)
        }
        return flags(for: key, modifiers: shortcut.modifiers, phase: phase)
    }

    static func flags(
        for key: KeyShortcutKey,
        modifiers: [KeyboardModifier],
        phase: ButtonPhase
    ) -> CGEventFlags {
        var eventFlags = flags(for: modifiers)
        guard key.key == "fn" else { return eventFlags }
        if phase == .pressed {
            eventFlags.insert(.maskSecondaryFn)
        } else {
            eventFlags.remove(.maskSecondaryFn)
        }
        return eventFlags
    }

    private static func layoutText(from event: CGEvent) -> String? {
        var actualLength = 0
        var characters = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(
            maxStringLength: characters.count,
            actualStringLength: &actualLength,
            unicodeString: &characters
        )
        guard actualLength > 0 else { return nil }
        return String(decoding: characters.prefix(actualLength), as: UTF16.self)
    }

    private static func normalizedLayoutText(_ text: String?) -> String? {
        guard let text else { return nil }
        let normalized = text.precomposedStringWithCanonicalMapping.lowercased()
        guard normalized.count == 1,
            normalized.unicodeScalars.allSatisfy({ scalar in
                !CharacterSet.controlCharacters.contains(scalar)
            })
        else {
            return nil
        }
        return normalized
    }

    private static let semanticNames: [CGKeyCode: String] = [
        36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape",
        63: "fn", 71: "keypad-clear", 76: "keypad-enter",
        96: "f5", 97: "f6", 98: "f7", 99: "f3", 100: "f8", 101: "f9",
        103: "f11", 105: "f13", 106: "f16", 107: "f14", 109: "f10",
        111: "f12", 113: "f15", 114: "help", 115: "home", 116: "page-up",
        117: "forward-delete", 118: "f4", 119: "end", 120: "f2",
        121: "page-down", 122: "f1", 123: "left", 124: "right",
        125: "down", 126: "up",
    ]

    private static let modifierFlags: [KeyboardModifier: CGEventFlags] = [
        .function: .maskSecondaryFn,
        .control: .maskControl,
        .option: .maskAlternate,
        .shift: .maskShift,
        .command: .maskCommand,
    ]

    private static let modifierKeyCodes: [KeyboardModifier: CGKeyCode] = [
        .function: 63,
        .control: 59,
        .option: 58,
        .shift: 56,
        .command: 55,
    ]

    private static let aliases: [String: CGKeyCode] = [
        "alt": 58,
        "backspace": 51,
        "cmd": 55,
        "command": 55,
        "control": 59,
        "ctrl": 59,
        "enter": 36,
        "fn": 63,
        "function": 63,
        "opt": 58,
        "option": 58,
        "shift": 56,
    ]

    private static let canonicalNames: [CGKeyCode: String] = [
        0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g",
        6: "z", 7: "x", 8: "c", 9: "v", 10: "section", 11: "b",
        12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "o", 32: "u", 33: "[", 34: "i", 35: "p",
        36: "return", 37: "l", 38: "j", 39: "'", 40: "k", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "n", 46: "m", 47: ".",
        48: "tab", 49: "space", 50: "grave", 51: "delete",
        53: "escape", 63: "fn", 64: "f17", 65: "keypad-decimal",
        67: "keypad-multiply", 69: "keypad-plus", 71: "keypad-clear",
        75: "keypad-divide", 76: "keypad-enter", 78: "keypad-minus",
        79: "f18", 80: "f19", 81: "keypad-equals", 82: "keypad-0",
        83: "keypad-1", 84: "keypad-2", 85: "keypad-3", 86: "keypad-4",
        87: "keypad-5", 88: "keypad-6", 89: "keypad-7", 90: "f20",
        91: "keypad-8", 92: "keypad-9", 96: "f5", 97: "f6", 98: "f7",
        99: "f3", 100: "f8", 101: "f9", 103: "f11", 105: "f13",
        106: "f16", 107: "f14", 109: "f10", 111: "f12", 113: "f15",
        114: "help", 115: "home", 116: "page-up", 117: "forward-delete",
        118: "f4", 119: "end", 120: "f2", 121: "page-down", 122: "f1",
        123: "left", 124: "right", 125: "down", 126: "up",
    ]
}
