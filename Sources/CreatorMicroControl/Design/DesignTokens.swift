import CreatorMicroCore
import SwiftUI

enum DesignTokens {
    static let popoverWidth: CGFloat = 392
    static let windowMinimumWidth: CGFloat = 840
    static let windowMinimumHeight: CGFloat = 620
    static let layerHUDWidth: CGFloat = 248
    static let layerHUDHeight: CGFloat = 76
    static let panelRadius: CGFloat = 12
    static let keyRadius: CGFloat = 9

    static let signal = Color(red: 36 / 255, green: 200 / 255, blue: 219 / 255)
    static let signalSoft = Color(red: 36 / 255, green: 200 / 255, blue: 219 / 255).opacity(0.14)
    static let graphite = Color(red: 23 / 255, green: 25 / 255, blue: 29 / 255)
    static let working = Color(red: 52 / 255, green: 120 / 255, blue: 246 / 255)
    static let ready = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)
    static let attention = Color(red: 1, green: 159 / 255, blue: 10 / 255)
    static let failure = Color(red: 1, green: 69 / 255, blue: 58 / 255)
    static let recording = Color(red: 34 / 255, green: 211 / 255, blue: 167 / 255)
}

extension Color {
    init?(creatorMicroHex value: String) {
        let trimmed = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard trimmed.count == 6, let number = UInt64(trimmed, radix: 16) else { return nil }
        self.init(
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255
        )
    }

    /// Decodes the shared `RGBColor` wire/device value directly from its packed
    /// `rawValue` (0xRRGGBB) — the same color the hardware payload builder sends.
    /// Explicitly module-qualified: `SwiftUI`'s AppKit import also exposes a C
    /// `RGBColor` (QuickDraw) with the same unqualified name.
    init(rgb value: CreatorMicroCore.RGBColor) {
        self.init(
            red: Double((value.rawValue >> 16) & 0xFF) / 255,
            green: Double((value.rawValue >> 8) & 0xFF) / 255,
            blue: Double(value.rawValue & 0xFF) / 255
        )
    }
}
