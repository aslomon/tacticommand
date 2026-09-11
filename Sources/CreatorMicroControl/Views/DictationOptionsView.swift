import CreatorMicroCore
import SwiftUI

enum DictationBindingEditor {
    static func choosing(
        _ provider: DictationProviderDefinition,
        from current: DictationBinding
    ) -> DictationBinding {
        let behavior =
            provider.supportedBehaviors.contains(current.behavior)
            ? current.behavior
            : provider.defaultBehavior
        return DictationBinding(
            providerID: provider.id,
            behavior: behavior,
            shortcut: provider.defaultShortcut
        )
    }

    static func replacingBehavior(
        _ behavior: DictationBehavior,
        in current: DictationBinding
    ) -> DictationBinding {
        DictationBinding(
            providerID: current.providerID,
            behavior: behavior,
            shortcut: current.shortcut
        )
    }

    static func replacingShortcut(
        _ shortcut: KeyShortcut?,
        in current: DictationBinding
    ) -> DictationBinding {
        DictationBinding(
            providerID: current.providerID,
            behavior: current.behavior,
            shortcut: shortcut
        )
    }
}

struct DictationOptionsView: View {
    let model: AppModel
    let action: Binding<CreatorAction>
    let binding: DictationBinding
    @State private var shortcutTestState = ShortcutTestState.idle

    var body: some View {
        Group {
            providerSection
            behaviorSection
            shortcutSection
        }
        .onChange(of: binding.shortcut) {
            shortcutTestState = .idle
        }
    }

    private var providerSection: some View {
        InspectorSection(title: "PROVIDER") {
            HStack {
                Picker("Provider", selection: providerSelection) {
                    ForEach(model.providers, id: \.id) { provider in
                        HStack {
                            Text(provider.displayName)
                            if provider.availability == .notInstalled {
                                Text("Not installed")
                            }
                        }
                        .tag(provider.id)
                    }
                }
                .labelsHidden()
                Button {
                    Task { await model.refreshProviders() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh installed applications")
            }
            Text(scopeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var behaviorSection: some View {
        InspectorSection(title: "BEHAVIOR") {
            Picker("Behavior", selection: behaviorSelection) {
                ForEach(supportedBehaviors, id: \.self) { behavior in
                    Text(behaviorLabel(behavior)).tag(behavior)
                }
            }
            .pickerStyle(.segmented)
            if supportedBehaviors == [.toggle] {
                Text("This provider exposes a toggle shortcut, not hold to talk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortcutSection: some View {
        InspectorSection(title: "SHORTCUT") {
            ShortcutEditorView(shortcut: shortcutSelection)
            Text(shortcutInstructions)
                .font(.caption)
                .foregroundStyle(needsShortcut ? DesignTokens.attention : .secondary)
            shortcutTestControls
        }
    }

    private var shortcutTestControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Test Shortcut") {
                    runShortcutTest()
                }
                .disabled(shortcutTestState == .running)
                if shortcutTestState == .running {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if let result = shortcutTestState.message {
                Label(result.text, systemImage: result.symbol)
                    .font(.caption)
                    .foregroundStyle(result.isError ? DesignTokens.failure : DesignTokens.ready)
            }
        }
    }

    private var providerSelection: Binding<DictationProviderID> {
        Binding(
            get: { binding.providerID },
            set: { id in
                guard let provider = model.provider(for: id) else { return }
                action.wrappedValue = .dictation(
                    DictationBindingEditor.choosing(provider, from: binding)
                )
            }
        )
    }

    private var behaviorSelection: Binding<DictationBehavior> {
        Binding(
            get: { binding.behavior },
            set: { behavior in
                guard supportedBehaviors.contains(behavior) else { return }
                action.wrappedValue = .dictation(
                    DictationBindingEditor.replacingBehavior(behavior, in: binding)
                )
            }
        )
    }

    private var shortcutSelection: Binding<KeyShortcut?> {
        Binding(
            get: { binding.shortcut },
            set: { shortcut in
                action.wrappedValue = .dictation(
                    DictationBindingEditor.replacingShortcut(shortcut, in: binding)
                )
            }
        )
    }

    private var supportedBehaviors: [DictationBehavior] {
        model.provider(for: binding.providerID)?.supportedBehaviors
            ?? [.toggle]
    }

    private func behaviorLabel(_ behavior: DictationBehavior) -> String {
        switch behavior {
        case .holdToTalk: "Hold to talk"
        case .toggle: "Toggle"
        }
    }

    private var scopeDescription: String {
        guard let provider = model.provider(for: binding.providerID) else {
            return "Provider information is unavailable."
        }
        if provider.id == .rede {
            return "System-wide: sends rede's shortcut into the current app without opening rede."
        }
        if needsShortcut {
            return "Record the provider's global shortcut before using this key."
        }
        return provider.scope == .systemWide
            ? "Routes dictation into the current text field."
            : "Works while \(provider.displayName) is focused."
    }

    private var needsShortcut: Bool {
        guard let provider = model.provider(for: binding.providerID) else { return true }
        return binding.shortcut == nil
            && provider.defaultShortcut == nil
    }

    private var shortcutInstructions: String {
        if binding.providerID == .rede {
            return
                "Record the same global shortcut configured in rede. Dictated text stays routed to the current text field."
        }
        if binding.providerID == .appleDictation {
            return "Apple's default is two fn taps. Record a different shortcut if System Settings uses one."
        }
        return needsShortcut
            ? "Record the same global shortcut configured in the dictation application."
            : "The recorded shortcut is sent exactly as shown above."
    }

    private func runShortcutTest() {
        shortcutTestState = .running
        Task {
            switch await model.testDictationShortcut(binding) {
            case .success:
                shortcutTestState = .success(
                    "Shortcut sent — confirm that dictation started."
                )
            case .failure(let failure):
                shortcutTestState = .failure(failure.message)
            }
        }
    }
}

private enum ShortcutTestState: Equatable {
    case idle
    case running
    case success(String)
    case failure(String)

    var message: (text: String, symbol: String, isError: Bool)? {
        switch self {
        case .idle, .running: nil
        case .success(let text): (text, "checkmark.circle.fill", false)
        case .failure(let text): (text, "exclamationmark.triangle.fill", true)
        }
    }
}
