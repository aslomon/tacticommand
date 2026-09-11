public enum DictationShortcutResolutionFailure: Error, Equatable, Sendable {
    case shortcutRequired(DictationProviderID)
    case unsupportedBehavior(
        providerID: DictationProviderID,
        behavior: DictationBehavior
    )
}

public struct DictationShortcutResolver: Sendable {
    public init() {}

    public func shortcut(
        for binding: DictationBinding
    ) -> Result<KeyShortcut, DictationShortcutResolutionFailure> {
        if isUnsupportedProviderBehavior(binding) {
            return .failure(
                .unsupportedBehavior(
                    providerID: binding.providerID,
                    behavior: binding.behavior
                )
            )
        }
        let resolution = resolveConfiguredOrDefaultShortcut(for: binding)
        return resolution.flatMap { shortcut in
            validate(shortcut: shortcut, for: binding)
        }
    }

    private func resolveConfiguredOrDefaultShortcut(
        for binding: DictationBinding
    ) -> Result<KeyShortcut, DictationShortcutResolutionFailure> {
        if let shortcut = binding.shortcut, !shortcut.isEmpty {
            return .success(shortcut)
        }
        if binding.providerID == .chatGPTCodex {
            return .success(KeyShortcut(key: "d", modifiers: [.control, .shift]))
        }
        if binding.providerID == .appleDictation {
            return .success(KeyShortcut(key: "fn", pressCount: 2))
        }
        return .failure(.shortcutRequired(binding.providerID))
    }

    private func validate(
        shortcut: KeyShortcut,
        for binding: DictationBinding
    ) -> Result<KeyShortcut, DictationShortcutResolutionFailure> {
        guard binding.behavior != .holdToTalk || shortcut.pressCount == 1 else {
            return .failure(
                .unsupportedBehavior(
                    providerID: binding.providerID,
                    behavior: binding.behavior
                )
            )
        }
        return .success(shortcut)
    }

    private func isUnsupportedProviderBehavior(_ binding: DictationBinding) -> Bool {
        binding.behavior == .holdToTalk
            && (binding.providerID == .appleDictation
                || binding.providerID == .chatGPTCodex)
    }
}
