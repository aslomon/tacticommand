import CreatorMicroCore
import SwiftUI

enum DialControlSelection {
    static let editableControls: [ControlID] = [
        .encoderCounterClockwise,
        .encoderPress,
        .encoderClockwise,
    ]

    static func title(for control: ControlID) -> String {
        switch control {
        case .encoderCounterClockwise: "CCW"
        case .encoderPress: "PRESS"
        case .encoderClockwise: "CW"
        default: control.rawValue
        }
    }
}

struct PadCanvasView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectedLayer.name)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("Select a control, then assign its action in the inspector.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(liveLabel, systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(isConnected ? DesignTokens.signal : .secondary)
            }
            .padding(.horizontal, 20)

            pad
                .padding(24)
                .background(DesignTokens.graphite, in: RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.14), radius: 18, y: 8)

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
    }

    private var pad: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                DialControl(model: model)
                ForEach(topRowAgentControls, id: \.self) { control in
                    MicroKey(control: control, model: model)
                }
                JoystickControl()
            }
            HStack(spacing: 10) {
                MicroKey(control: .agent2, model: model)
                MicroKey(control: .agent3, model: model)
                MicroKey(control: .agent4, model: model)
                MicroKey(control: .agent5, model: model)
            }
            HStack(spacing: 10) {
                MicroKey(control: .action6, model: model)
                MicroKey(control: .action7, model: model)
                MicroKey(control: .action8, model: model)
                MicroKey(control: .action9, model: model)
            }
            HStack(spacing: 10) {
                TouchControl()
                microphoneControls
                MicroKey(control: .action12, model: model)
            }
            layerIndicators
        }
    }

    /// Input geometry comes from the device capability, not an assumed LED wiring order.
    /// Verified Creator Micro 2 inputs and the historical Codex layout place AG0 left
    /// of AG1. Saved bindings and firmware lighting slot identifiers stay unchanged.
    private var topRowAgentControls: [ControlID] {
        model.capabilityProfile.topRowOrdering == .rightToLeft
            ? [.agent1, .agent0]
            : [.agent0, .agent1]
    }

    @ViewBuilder
    private var microphoneControls: some View {
        if model.capabilityProfile.wideKeyPair != nil {
            // Creator's microphone switches share one physical wide cap: only action10
            // is reachable, and its label reflects whatever action is actually bound to
            // it (never a hardcoded "DICTATE"). action11's saved binding is preserved
            // untouched for when the same configuration connects to a 6-key device.
            MicroKey(control: .action10, model: model, width: 142, physicallySharedWith: .action11)
        } else {
            switch model.configuration.microphoneLayout {
            case .linked:
                MicroKey(control: .action10, model: model, width: 142)
            case .separate:
                HStack(spacing: 6) {
                    MicroKey(control: .action10, model: model, width: 68, labelOverride: "MIC")
                    MicroKey(control: .action11, model: model, width: 68, labelOverride: "APPROVE")
                }
            }
        }
    }

    private var layerIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(
                        index == model.deviceStatus?.profileIndex
                            ? DesignTokens.signal
                            : Color.white.opacity(0.16)
                    )
                    .frame(width: 24, height: 4)
            }
        }
        .padding(.top, 4)
        .accessibilityLabel(profileAccessibilityLabel)
    }

    private var isConnected: Bool {
        if case .connected = model.connectionState { return true }
        return false
    }

    private var liveLabel: String {
        isConnected ? "Hardware live" : "Hardware offline"
    }

    private var profileAccessibilityLabel: String {
        guard let profile = model.deviceStatus?.profileIndex else {
            return "Bluetooth profile unknown"
        }
        return "Bluetooth profile \(profile + 1)"
    }
}

private struct DialControl: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 5) {
            Button {
                model.select(control: .encoderPress)
            } label: {
                ZStack {
                    Circle().fill(Color.black.opacity(0.58))
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
                    Capsule()
                        .fill(DesignTokens.signal)
                        .frame(width: 3, height: 18)
                        .offset(y: -12)
                }
                .frame(width: 68, height: 68)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select dial press")

            HStack(spacing: 2) {
                ForEach(DialControlSelection.editableControls, id: \.self) { control in
                    selectionButton(for: control)
                }
            }
        }
        .frame(width: 92)
    }

    private func selectionButton(for control: ControlID) -> some View {
        Button {
            model.select(control: control)
        } label: {
            Text(DialControlSelection.title(for: control))
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(model.selectedControl == control ? Color.black : Color.white)
                .frame(maxWidth: .infinity, minHeight: 20)
                .background(
                    model.selectedControl == control
                        ? DesignTokens.signal
                        : Color.white.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select dial \(DialControlSelection.title(for: control))")
    }
}

private struct JoystickControl: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.58))
            Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
            Circle().fill(DesignTokens.signal.opacity(0.7)).frame(width: 22, height: 22)
        }
        .frame(width: 68, height: 68)
        .accessibilityLabel("Configurable joystick")
    }
}

private struct TouchControl: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.58))
            Circle().stroke(Color.white.opacity(0.2), lineWidth: 2)
            Image(systemName: "hand.tap")
                .foregroundStyle(DesignTokens.signal)
        }
        .frame(width: 68, height: 54)
        .accessibilityLabel("Firmware touch and Bluetooth profile control")
    }
}
