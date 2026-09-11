import CreatorMicroCore
import SwiftUI

struct BindingInspectorView: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                LayerJoystickOptionsView(model: model)
                ActionBindingPickerView(model: model)
                microphoneLayout
                ActionBranchOptionsView(model: model)
                Divider()
                hardwareNote
            }
            .padding(16)
        }
        .background(Color.primary.opacity(0.025))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.selectedControl.rawValue)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignTokens.signal)
            Text(model.selectedAction.actionTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
    }

    @ViewBuilder
    private var microphoneLayout: some View {
        if model.selectedControl == .action10 || model.selectedControl == .action11 {
            InspectorSection(title: "MICROPHONE SWITCHES") {
                Toggle("Use two separate keys", isOn: separateMicrophoneBinding)
                Text(
                    isSeparate
                        ? "Left and right trigger independent actions."
                        : "Both switches produce one deduplicated action."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var hardwareNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Physical control", systemImage: "memorychip")
                .font(.system(size: 12, weight: .medium))
            Text(hardwareDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var isSeparate: Bool {
        model.configuration.microphoneLayout == .separate
    }

    private var separateMicrophoneBinding: Binding<Bool> {
        Binding(
            get: { isSeparate },
            set: { model.setMicrophoneLayout($0 ? .separate : .linked) }
        )
    }

    private var hardwareDescription: String {
        switch model.selectedControl {
        case .action10: "Left switch under the microphone position."
        case .action11: "Right switch under the microphone position."
        case .encoderClockwise, .encoderCounterClockwise: "One pulse per dial detent."
        case .encoderPress: "Press the rotary dial."
        default: "Vendor HID control \(model.selectedControl.rawValue)."
        }
    }
}
