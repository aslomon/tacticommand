import AppKit
import CreatorMicroCore
import SwiftUI

struct ShortcutEditorView: View {
    @Binding var shortcut: KeyShortcut?
    @State private var recorder = MacShortcutRecorder()
    @State private var recordingPresentation = ShortcutRecordingPresentationState()
    @State private var recorderMessage: String?
    @State private var messageIsError = false
    @State private var showsAdvanced = false
    @State private var keyboardLayoutName = MacKeyboardLayout.currentDisplayName

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            recorderControls
            if let recorderMessage {
                Text(recorderMessage)
                    .font(.caption)
                    .foregroundStyle(messageIsError ? DesignTokens.failure : .secondary)
            }
            DisclosureGroup(
                "Advanced / manual entry",
                isExpanded: $showsAdvanced
            ) {
                advancedEditor
            }
            .font(.caption)
        }
        .onDisappear {
            recorder.cancel(notify: false)
            recordingPresentation.viewDidDisappear()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSTextInputContext.keyboardSelectionDidChangeNotification
            )
        ) { _ in
            keyboardLayoutName = MacKeyboardLayout.currentDisplayName
        }
    }

    private var recorderControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                shortcutPreview
                Button(isRecording ? "Cancel Recording" : "Record Shortcut") {
                    toggleRecording()
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? DesignTokens.attention : DesignTokens.signal)
            }
            if isRecording {
                VStack(alignment: .leading, spacing: 3) {
                    Label(
                        "Hold modifiers alone, or add one or more main keys together.",
                        systemImage: "keyboard"
                    )
                    Text("Release the complete chord to save it, including fn/ctrl/opt/shift/cmd.")
                    Text("Keyboard layout: \(keyboardLayoutName)")
                }
                .font(.caption)
                .foregroundStyle(DesignTokens.signal)
            }
        }
    }

    private var shortcutPreview: some View {
        Text(formattedShortcut)
            .font(.system(.body, design: .monospaced, weight: .semibold))
            .foregroundStyle(shortcut == nil ? .secondary : .primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? DesignTokens.signal : .secondary.opacity(0.25))
            }
            .accessibilityLabel("Recorded shortcut: \(formattedShortcut)")
    }

    private var advancedEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Key, for example d or f5", text: keyBinding)
                .textFieldStyle(.roundedBorder)
            modifierButtons
            timingControls
            Button("Clear shortcut") {
                shortcut = nil
                showMessage("Shortcut cleared.", isError: false)
            }
            .buttonStyle(.link)
        }
        .padding(.top, 6)
    }

    private var modifierButtons: some View {
        HStack(spacing: 5) {
            ForEach(KeyboardModifier.allCases, id: \.self) { modifier in
                Button(modifierLabel(modifier)) {
                    toggle(modifier)
                }
                .buttonStyle(.bordered)
                .tint(activeModifiers.contains(modifier) ? DesignTokens.signal : .secondary)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var timingControls: some View {
        if let shortcut {
            Stepper(
                "Presses: \(shortcut.pressCount)",
                value: pressCountBinding,
                in: 1...4
            )
            .controlSize(.small)
            if shortcut.pressCount > 1 {
                Stepper(
                    "Tap interval: \(shortcut.interTapIntervalMilliseconds) ms",
                    value: tapIntervalBinding,
                    in: 30...1_000,
                    step: 10
                )
                .controlSize(.small)
            }
        }
    }

    private var formattedShortcut: String {
        shortcut.map(KeyShortcutDisplayFormatter().string) ?? "No shortcut recorded"
    }

    private var isRecording: Bool {
        recordingPresentation.isRecording
    }

    private var activeModifiers: Set<KeyboardModifier> {
        Set(shortcut?.modifiers ?? [])
    }

    private var keyBinding: Binding<String> {
        Binding(
            get: { shortcut?.key ?? "" },
            set: { key in
                let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
                shortcut = trimmed.isEmpty ? modifierOnlyShortcut() : manualShortcut(key: trimmed)
            }
        )
    }

    private var pressCountBinding: Binding<Int> {
        Binding(
            get: { shortcut?.pressCount ?? 1 },
            set: { pressCount in
                guard shortcut != nil else { return }
                self.shortcut = updatedShortcut(
                    pressCount: pressCount
                )
            }
        )
    }

    private var tapIntervalBinding: Binding<Int> {
        Binding(
            get: { shortcut?.interTapIntervalMilliseconds ?? 120 },
            set: { milliseconds in
                guard shortcut != nil else { return }
                self.shortcut = updatedShortcut(
                    interTapIntervalMilliseconds: milliseconds
                )
            }
        )
    }

    private func toggleRecording() {
        if isRecording {
            recorder.cancel()
            return
        }
        keyboardLayoutName = MacKeyboardLayout.currentDisplayName
        showMessage("Waiting for a physical shortcut…", isError: false)
        switch recorder.start(onDecision: handleRecordingDecision) {
        case .success:
            recordingPresentation.recordingStarted()
        case .failure(let failure):
            showMessage(message(for: failure), isError: true)
        }
    }

    private func handleRecordingDecision(_ decision: ShortcutRecordingDecision) {
        recordingPresentation.handle(decision)
        switch decision {
        case .captured(let recordedShortcut):
            shortcut = recordedShortcut.renamed(to: shortcut?.displayName)
            showMessage("Recorded \(formattedShortcut).", isError: false)
        case .cancelled:
            showMessage("Recording cancelled.", isError: false)
        case .cleared:
            shortcut = nil
            showMessage("Shortcut cleared.", isError: false)
        case .keepRecording:
            break
        }
    }

    private func showMessage(_ message: String, isError: Bool) {
        recorderMessage = message
        messageIsError = isError
    }

    private func message(for failure: MacShortcutRecorderFailure) -> String {
        switch failure {
        case .accessibilityPermissionRequired:
            "Accessibility access is required to record and suppress shortcuts."
        case .eventTapUnavailable:
            "macOS could not start shortcut recording. Try again after reopening settings."
        }
    }

    private func toggle(_ modifier: KeyboardModifier) {
        var modifiers = activeModifiers
        if modifiers.contains(modifier) {
            modifiers.remove(modifier)
        } else {
            modifiers.insert(modifier)
        }
        if modifiers.isEmpty, shortcut?.mainKeys.isEmpty != false {
            shortcut = nil
        } else {
            shortcut = updatedShortcut(modifiers: Array(modifiers))
        }
    }

    private func updatedShortcut(
        modifiers: [KeyboardModifier]? = nil,
        pressCount: Int? = nil,
        interTapIntervalMilliseconds: Int? = nil
    ) -> KeyShortcut {
        KeyShortcut(
            mainKeys: shortcut?.mainKeys ?? [],
            modifiers: modifiers ?? shortcut?.modifiers ?? [],
            pressCount: pressCount ?? shortcut?.pressCount ?? 1,
            interTapIntervalMilliseconds: interTapIntervalMilliseconds
                ?? shortcut?.interTapIntervalMilliseconds
                ?? 120,
            displayName: shortcut?.displayName
        )
    }

    private func modifierOnlyShortcut() -> KeyShortcut? {
        guard let shortcut, !shortcut.modifiers.isEmpty else { return nil }
        return KeyShortcut(
            mainKeys: [],
            modifiers: shortcut.modifiers,
            pressCount: shortcut.pressCount,
            interTapIntervalMilliseconds: shortcut.interTapIntervalMilliseconds,
            displayName: shortcut.displayName
        )
    }

    private func manualShortcut(key: String) -> KeyShortcut {
        KeyShortcut(
            key: key,
            modifiers: shortcut?.modifiers ?? [],
            pressCount: shortcut?.pressCount ?? 1,
            interTapIntervalMilliseconds: shortcut?.interTapIntervalMilliseconds ?? 120,
            virtualKeyCode: MacVirtualKeyMap.keyCodeForCurrentLayout(for: key),
            displayName: shortcut?.displayName
        )
    }

    private func modifierLabel(_ modifier: KeyboardModifier) -> String {
        switch modifier {
        case .function: "fn"
        case .control: "ctrl"
        case .option: "opt"
        case .shift: "shift"
        case .command: "cmd"
        }
    }
}
