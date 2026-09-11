import CreatorMicroCore
import SwiftUI

struct ConfigurationWindowView: View {
    let model: AppModel
    @State private var isDeviceBrowserPresented = false

    var body: some View {
        VStack(spacing: 0) {
            ConfigurationHeader(
                model: model,
                showDevices: { isDeviceBrowserPresented = true }
            )
            if !model.systemAccess.isComplete {
                SystemAccessBanner(model: model)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            if let error = model.lastError {
                InlineErrorView(message: error, dismiss: model.clearLastError)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            Divider()
            HStack(spacing: 0) {
                LayerRailView(model: model)
                    .frame(width: 168)
                Divider()
                PadCanvasView(model: model)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                BindingInspectorView(model: model)
                    .frame(width: 292)
            }
            .disabled(!model.isReady)
        }
        .frame(
            minWidth: DesignTokens.windowMinimumWidth,
            minHeight: DesignTokens.windowMinimumHeight
        )
        .background(.background)
        .onAppear {
            model.refreshSystemAccess()
            model.refreshDeviceInventory()
        }
        .sheet(isPresented: $isDeviceBrowserPresented) {
            MicroDeviceManagementView(model: model)
        }
    }
}

private struct ConfigurationHeader: View {
    let model: AppModel
    let showDevices: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AppLogoView(size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppIdentity.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text(connectionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let firmware = model.deviceStatus?.version {
                Text("Firmware \(firmware)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if let profile = model.deviceStatus?.profileIndex {
                Label("Host \(profile + 1)", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.signal)
            }
            Button(action: showDevices) {
                Label("Devices", systemImage: "dot.radiowaves.left.and.right")
            }
            .buttonStyle(.bordered)
            Button {
                model.reconnect()
            } label: {
                Label("Reconnect", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .frame(height: 58)
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
}
