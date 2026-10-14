import AppKit
import SwiftUI

struct MicroDeviceManagementView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSetupGuidePresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            connectedSection
            if !previouslySeenDevices.isEmpty {
                previouslySeenSection
            }
            Divider()
            connectionHelp
            footer
        }
        .padding(22)
        .frame(width: 500)
        .task { model.refreshDeviceInventory() }
        .sheet(isPresented: $isSetupGuidePresented) {
            SetupGuideView(model: model)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            AppLogoView(size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Label("Micro Devices", systemImage: "dot.radiowaves.left.and.right")
                    .font(.title2.weight(.semibold))
                Text("Connected Creator Micro-compatible controllers available to this app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONNECTED TO THIS MAC")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            if model.detectedDevices.isEmpty {
                unavailableDeviceCard
            } else {
                ForEach(model.detectedDevices) { device in
                    deviceCard(device)
                }
            }
        }
    }

    private func deviceCard(_ device: MicroDeviceRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.grid.2x2.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(DesignTokens.ready)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.headline)
                Text(device.connectionLabel + serialSuffix(for: device))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(DesignTokens.ready)
        }
        .padding(14)
        .background(DesignTokens.ready.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableDeviceCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("No compatible Micro is connected")
                    .font(.headline)
                Text("Supported names include Codex Micro and Creator Micro.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var previouslySeenSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREVIOUSLY SEEN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            ForEach(previouslySeenDevices) { device in
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.name)
                            .font(.headline)
                        Text("Last seen over \(device.connectionLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Connect in macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var connectionHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Pairing stays with macOS", systemImage: "lock.shield")
                .font(.headline)
            Text(
                "Bluetooth HID pairing and nearby-device discovery are managed by System Settings. "
                    + "Connect a Micro there; this app detects it automatically and can then reconnect its control session."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                model.refreshDeviceInventory()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Button {
                model.reconnect()
            } label: {
                Label("Reconnect App", systemImage: "bolt.horizontal.circle")
            }
            Button {
                isSetupGuidePresented = true
            } label: {
                Label("Setup Guide", systemImage: "checkmark.shield")
            }
            Spacer()
            Button {
                NSWorkspace.shared.open(MicroDeviceInventoryPresentation.bluetoothSettingsURL)
            } label: {
                Label("Bluetooth Settings", systemImage: "gear")
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.signal)
        }
    }

    private func serialSuffix(for device: MicroDeviceRecord) -> String {
        guard let serialNumber = device.serialNumber else { return "" }
        return " · \(serialNumber)"
    }

    private var previouslySeenDevices: [MicroDeviceRecord] {
        let connectedIdentifiers = Set(model.detectedDevices.map(\.identifier))
        return model.knownDevices.filter {
            !connectedIdentifiers.contains($0.identifier)
        }
    }
}
