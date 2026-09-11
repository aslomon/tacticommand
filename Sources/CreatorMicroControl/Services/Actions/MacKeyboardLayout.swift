import AppKit
import Carbon

enum MacKeyboardLayout {
    static var currentDisplayName: String {
        if let systemName = currentSystemLayoutName() {
            return systemName
        }
        return displayName(
            identifier: NSTextInputContext.current?.selectedKeyboardInputSource,
            localizedName: { identifier in
                NSTextInputContext.localizedName(forInputSource: identifier)
            }
        )
    }

    static func displayName(
        identifier: String?,
        localizedName: (String) -> String?
    ) -> String {
        guard let identifier, !identifier.isEmpty else {
            return "Current macOS layout"
        }
        if let name = localizedName(identifier), !name.isEmpty {
            return name
        }
        guard let suffix = identifier.split(separator: ".").last else {
            return "Current macOS layout"
        }
        return String(suffix)
    }

    private static func currentSystemLayoutName() -> String? {
        guard let retainedSource = TISCopyCurrentKeyboardLayoutInputSource() else {
            return nil
        }
        let source = retainedSource.takeRetainedValue()
        if let localizedName = propertyString(
            TISGetInputSourceProperty(source, kTISPropertyLocalizedName)
        ) {
            return localizedName
        }
        let identifier = propertyString(
            TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        )
        return displayName(identifier: identifier) { _ in nil }
    }

    private static func propertyString(
        _ pointer: UnsafeMutableRawPointer?
    ) -> String? {
        guard let pointer else { return nil }
        let value = Unmanaged<CFString>
            .fromOpaque(pointer)
            .takeUnretainedValue()
        let encoding = CFStringBuiltInEncodings.UTF8.rawValue
        let capacity =
            CFStringGetMaximumSizeForEncoding(
                CFStringGetLength(value),
                encoding
            ) + 1
        var buffer = [CChar](repeating: 0, count: capacity)
        guard CFStringGetCString(value, &buffer, capacity, encoding) else {
            return nil
        }
        let bytes = buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
        return String(decoding: bytes, as: UTF8.self)
    }
}
