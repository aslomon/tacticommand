import CreatorMicroCore
import SwiftUI

/// Entry points: the configuration header and Device Management (`MicroDeviceManagementView`).
/// Read-only until the user explicitly confirms Provision or Restore; see DESIGN.md
/// "Setup Guide" for the approved copy and consent rules.
struct SetupGuideView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var provisionToken: UUID?
    @State private var provisionLayerSummary = ""
    @State private var isProvisionConfirmationPresented = false
    @State private var isRestoreConfirmationPresented = false
    // Not `private`: mutated from `SetupGuideActions.swift`'s extension.
    @State var didCopyBackupPath = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    permissionsSection
                    connectionSection
                    firmwareSection
                    if let error = model.deviceSetupError {
                        InlineErrorView(message: error) { model.deviceSetupError = nil }
                    }
                    backupSection
                    layerExplanationSection
                    firmwareLinkSection
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 580)
        .task { await model.inspectDeviceSetup() }
        .confirmationDialog(
            "Replace the active physical layer?",
            isPresented: $isProvisionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Replace Layer", role: .destructive) { confirmProvision() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "\(provisionLayerSummary) will be replaced with TactiCommand's Creator mapping. "
                    + "Every other physical layer is preserved, and the complete original keymap "
                    + "is backed up first."
            )
        }
        .confirmationDialog(
            "Restore the backed-up layer?",
            isPresented: $isRestoreConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Restore Backup", role: .destructive) {
                Task { await model.restoreDeviceSetup(consent: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Restores the physical layer saved in that backup and preserves every other "
                    + "current physical layer. The current full keymap is backed up again first."
            )
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            AppLogoView(size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Label("Setup Guide", systemImage: "checkmark.shield")
                    .font(.title3.weight(.semibold))
                Text("Inspect and, only with your confirmation, prepare the controller's firmware.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    @ViewBuilder
    private var permissionsSection: some View {
        InspectorSection(title: "PERMISSIONS") {
            if model.systemAccess.isComplete {
                Label("Accessibility and Input Monitoring granted", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(DesignTokens.ready)
            } else {
                SystemAccessBanner(model: model)
            }
        }
    }

    private var connectionSection: some View {
        InspectorSection(title: "CONNECTION") {
            HStack(spacing: 8) {
                Circle().fill(connectionColor).frame(width: 7, height: 7)
                Text(connectionText)
                    .font(.callout)
                Spacer()
                Text(modelDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var firmwareSection: some View {
        InspectorSection(title: "FIRMWARE & PHYSICAL LAYER") {
            VStack(alignment: .leading, spacing: 10) {
                refreshRow
                if let inspection = model.deviceSetupInspection {
                    readinessRow(inspection)
                    firmwareGuidance(inspection)
                } else if !model.deviceSetupBusy {
                    Text("Not yet inspected. Inspecting never writes anything by itself.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var refreshRow: some View {
        HStack(spacing: 8) {
            Button {
                Task { await model.inspectDeviceSetup() }
            } label: {
                Label("Inspect / Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(model.deviceSetupBusy)
            if model.deviceSetupBusy {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func readinessRow(_ inspection: FirmwareSetupInspection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: inspection.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(inspection.isReady ? DesignTokens.ready : DesignTokens.attention)
            Text(
                "Layer \(inspection.rawLayer) (\"\(inspection.layerName)\") — "
                    + (inspection.isReady ? "ready" : "not prepared")
            )
            .font(.callout)
        }
    }

    @ViewBuilder
    private func firmwareGuidance(_ inspection: FirmwareSetupInspection) -> some View {
        switch inspection.model {
        case .creator13:
            if inspection.canProvision {
                Button {
                    requestProvisionConfirmation(inspection)
                } label: {
                    Label("Provision TactiCommand Layer", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.signal)
                .disabled(model.deviceSetupBusy)
            } else {
                Text("This physical layer already matches TactiCommand's Creator mapping.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .codex6:
            Text(
                "Codex's own layout is checked against TactiCommand's expected bindings; TactiCommand "
                    + "never writes Codex firmware. Use Work Louder's official configurator to change it."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        case .unknown:
            Text("This model isn't recognized. TactiCommand makes no automatic firmware changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var backupSection: some View {
        if let path = model.deviceSetupBackupPath {
            InspectorSection(title: "BACKUP") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    HStack(spacing: 8) {
                        Button(didCopyBackupPath ? "Copied" : "Copy Path") { copyBackupPath(path) }
                            .buttonStyle(.bordered)
                        Button("Reveal in Finder") { revealBackupPath(path) }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Restore Backup") { isRestoreConfirmationPresented = true }
                            .buttonStyle(.bordered)
                            .disabled(model.deviceSetupBusy || !model.deviceSetupCanRestore)
                    }
                    if !model.deviceSetupCanRestore {
                        Text("Restore only works on the exact connection that created this backup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("This file stays on disk across restarts and reconnects.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var layerExplanationSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Two separate kinds of layer", systemImage: "square.3.layers.3d")
                .font(.system(size: 12, weight: .medium))
            Text(
                "Switching the controller's onboard physical-layer control changes which physical "
                    + "keymap is active on the device itself. TactiCommand's ten software layers are "
                    + "a separate, app-side concept and are not affected by it."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var firmwareLinkSection: some View {
        if model.capabilityProfile.model == .creator13 {
            VStack(alignment: .leading, spacing: 4) {
                Link(
                    "Creator Micro firmware v0.6.3 release notes ↗",
                    destination: URL(string: "https://github.com/worklouder/cm-v2-fw-releases/releases/tag/v0.6.3")!
                )
                .font(.callout)
                Text("Scoped to this model only — not a claim that it is the latest release for every device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func confirmProvision() {
        guard let token = provisionToken else { return }
        Task { await model.provisionDeviceSetup(token: token, consent: true) }
    }

    private func requestProvisionConfirmation(_ inspection: FirmwareSetupInspection) {
        provisionToken = inspection.token
        provisionLayerSummary = "Layer \(inspection.rawLayer) (\"\(inspection.layerName)\")"
        isProvisionConfirmationPresented = true
    }

    private var connectionText: String {
        switch model.connectionState {
        case .disconnected: "Waiting for Codex Micro / Creator Micro 2"
        case .connecting: "Connecting"
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

    private var modelDisplayName: String {
        switch model.capabilityProfile.model {
        case .creator13: "Creator Micro 2"
        case .codex6: "Codex Micro"
        case .unknown: "Unrecognized model"
        }
    }
}
