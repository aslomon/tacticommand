import AppKit
import CreatorMicroCore
import SwiftUI

struct MenuBarRootView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statusStrip
            layerPicker
            if !model.systemAccess.isComplete {
                SystemAccessBanner(model: model)
            }
            if let error = model.lastError {
                InlineErrorView(message: error, dismiss: model.clearLastError)
            }
            dictationPicker
            Divider()
            footer
        }
        .padding(16)
        .frame(width: DesignTokens.popoverWidth)
        .onAppear {
            model.refreshSystemAccess()
        }
        .task {
            await model.refreshProviders()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppLogoView(size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppIdentity.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(connectionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
                .accessibilityLabel(connectionLabel)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            StatusChip(
                symbol: "square.3.layers.3d",
                text: layerStatusText,
                color: DesignTokens.signal
            )
            if let battery = model.deviceStatus?.batteryPercentage {
                StatusChip(
                    symbol: battery < 20 ? "battery.25" : "battery.75",
                    text: "\(battery)%",
                    color: battery < 20 ? DesignTokens.attention : .secondary
                )
            }
            if let profile = model.deviceStatus?.profileIndex {
                StatusChip(
                    symbol: "antenna.radiowaves.left.and.right",
                    text: "Host \(profile + 1)",
                    color: DesignTokens.signal
                )
            }
            StatusChip(
                symbol: microphoneStatus.symbol,
                text: microphoneStatus.text,
                color: microphoneStatus.color
            )
            Spacer()
        }
    }

    private var dictationPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DICTATION")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Picker("Provider", selection: providerSelection) {
                ForEach(model.providers, id: \.id) { provider in
                    Text(provider.displayName).tag(provider.id)
                }
            }
            .labelsHidden()
            Text(providerScopeText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!model.isReady)
    }

    private var layerPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SOFTWARE LAYER")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Picker("Active software layer", selection: activeLayerSelection) {
                ForEach(model.configuration.layers) { layer in
                    Text("\(layer.id.rawValue + 1) · \(layer.name)").tag(layer.id)
                }
            }
            .labelsHidden()
            Text("Choose here or press the rightmost key in the four-key row (ACT09) to cycle.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("The round haptic control changes Bluetooth host 1–3, not this layer.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Toggle("Launch at Login", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!model.isReady)
            HStack {
                SettingsLink {
                    Text("Configure Pad")
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.signal)
                Spacer()
                Button(ApplicationQuitCommand.title) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(
                    KeyEquivalent(ApplicationQuitCommand.keyEquivalent),
                    modifiers: .command
                )
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginEnabled },
            set: { enabled in model.setLaunchAtLogin(enabled) }
        )
    }

    private var providerSelection: Binding<DictationProviderID> {
        Binding(
            get: { model.currentDictationBinding?.providerID ?? .rede },
            set: { id in
                guard let provider = model.provider(for: id) else { return }
                model.chooseProvider(provider)
            }
        )
    }

    private var activeLayerSelection: Binding<LayerIndex> {
        Binding(
            get: { model.activeLayer },
            set: { model.select(layer: $0) }
        )
    }

    private var microphoneStatus: (symbol: String, text: String, color: Color) {
        switch model.audioSnapshot.inputMute {
        case .muted:
            ("mic.slash.fill", "Muted", DesignTokens.failure)
        case .unmuted:
            ("mic.fill", "Mic on", DesignTokens.ready)
        case .mixed:
            ("mic.badge.xmark", "Mic mixed", DesignTokens.attention)
        case .unavailable:
            ("mic.badge.questionmark", "Mic unknown", DesignTokens.attention)
        }
    }

    private var layerStatusText: String {
        let presentation = LayerSelectionPresentation(
            state: model.layerSelection,
            layerName: model.selectedLayer.name
        )
        return "\(model.selectedLayer.name) · \(presentation.sourceLabel)"
    }

    private var providerScopeText: String {
        guard let id = model.currentDictationBinding?.providerID,
            let provider = model.provider(for: id)
        else {
            return "Select a provider for the microphone key."
        }
        if providerNeedsShortcut(provider, binding: model.currentDictationBinding) {
            return "Shortcut setup required in Configure Pad"
        }
        return provider.scope == .systemWide
            ? "Available in any text field"
            : "Available while the provider app is focused"
    }

    private func providerNeedsShortcut(
        _ provider: DictationProviderDefinition,
        binding: DictationBinding?
    ) -> Bool {
        binding?.shortcut == nil
            && provider.defaultShortcut == nil
    }

    private var connectionLabel: String {
        switch model.connectionState {
        case .disconnected: "Micro disconnected"
        case .connecting: "Connecting to Micro"
        case .connected(let transport, _):
            transport == .usb ? "Connected over USB" : "Connected over Bluetooth"
        case .unavailable(let reason): reason
        }
    }

    private var connectionColor: Color {
        if case .connected = model.connectionState { return DesignTokens.ready }
        if case .connecting = model.connectionState { return DesignTokens.attention }
        return .secondary
    }
}

private struct StatusChip: View {
    let symbol: String
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.1), in: Capsule())
    }
}
