import SwiftUI

struct SystemAccessBanner: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(DesignTokens.attention)
                VStack(alignment: .leading, spacing: 2) {
                    Text("System control needs access")
                        .font(.system(size: 12, weight: .semibold))
                    Text(accessExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 8) {
                Spacer()
                accessButtons
            }
        }
        .padding(12)
        .background(
            DesignTokens.attention.opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: DesignTokens.panelRadius,
                style: .continuous
            ))
    }

    @ViewBuilder
    private var accessButtons: some View {
        if model.systemAccess.accessibility != .granted {
            Button("Enable Control") {
                model.requestAccessibility()
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.signal)
        } else if model.systemAccess.inputMonitoring != .granted {
            Button("Enable Input") {
                model.requestInputMonitoring()
            }
            .buttonStyle(.bordered)
        }
        Button {
            model.openPrivacySettings()
        } label: {
            Label(privacySettingsTitle, systemImage: "gear")
        }
        .buttonStyle(.borderless)
        .help(privacySettingsTitle)
    }

    private var accessExplanation: String {
        if model.systemAccess.accessibility != .granted {
            return "Required for keys, dictation shortcuts, and the pointer."
        }
        return "Input Monitoring is required to receive pad events."
    }

    private var privacySettingsTitle: String {
        if model.systemAccess.accessibility != .granted {
            return "Open Accessibility"
        }
        return "Open Input Monitoring"
    }
}
