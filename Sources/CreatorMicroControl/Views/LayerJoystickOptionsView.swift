import CreatorMicroCore
import SwiftUI

struct JoystickModePresentation: Equatable {
    let title: String
    let symbol: String
    let detail: String

    init(title: String, symbol: String, detail: String) {
        self.title = title
        self.symbol = symbol
        self.detail = detail
    }

    init(_ mode: JoystickMode) {
        switch mode {
        case .arrowKeys:
            title = "Arrow Keys"
            symbol = "arrow.up.and.down.and.arrow.left.and.right"
            detail = "Holds the matching arrow key while the stick is deflected."
        case .pointer:
            title = "Mouse Pointer"
            symbol = "cursorarrow.motionlines"
            detail = "Moves the macOS pointer with fine control near the centre."
        case .off:
            title = "Off"
            symbol = "power"
            detail = "Ignores joystick movement on this layer."
        }
    }
}

enum JoystickSectionPresentation {
    static func summary(for override: LayerJoystickConfiguration?) -> String {
        guard let override else { return "Inherited · Mouse Pointer" }
        return "This layer · \(JoystickModePresentation(override.mode).title)"
    }
}

struct LayerJoystickOptionsView: View {
    let model: AppModel
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Use custom settings for this layer", isOn: overrideBinding)
                if let override = model.selectedLayerJoystickOverride {
                    modePicker
                    if override.mode != .off {
                        deadZoneControl(override.deadZone)
                    }
                    if override.mode == .pointer {
                        speedControl(override.maximumSpeed)
                    }
                } else {
                    Text(
                        "This layer uses the global mouse-pointer response. Enable custom settings to choose another mode."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(spacing: 8) {
                Label("Joystick", systemImage: "dot.scope")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(JoystickSectionPresentation.summary(for: model.selectedLayerJoystickOverride))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MODE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(JoystickMode.allCases, id: \.self) { mode in
                modeButton(for: mode)
            }
        }
    }

    private func modeButton(for mode: JoystickMode) -> some View {
        let presentation = JoystickModePresentation(mode)
        let isSelected = model.selectedLayerJoystickOverride?.mode == mode
        return Button {
            model.setLayerJoystickMode(mode)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: presentation.symbol)
                    .frame(width: 18)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(presentation.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 6)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(
                isSelected ? Color.accentColor.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func deadZoneControl(_ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Dead zone")
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, design: .monospaced))
            }
            Slider(value: deadZoneBinding, in: 0...0.95)
        }
    }

    private func speedControl(_ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Maximum speed")
                Spacer()
                Text("\(Int(value)) px/s")
                    .font(.system(size: 11, design: .monospaced))
            }
            Slider(value: speedBinding, in: 100...4_000, step: 50)
        }
    }

    private var overrideBinding: Binding<Bool> {
        Binding(
            get: { model.selectedLayerJoystickOverride != nil },
            set: { model.setLayerJoystickOverrideEnabled($0) }
        )
    }

    private var deadZoneBinding: Binding<Double> {
        Binding(
            get: { model.selectedLayerJoystickOverride?.deadZone ?? 0.12 },
            set: { model.setLayerJoystickDeadZone($0) }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { model.selectedLayerJoystickOverride?.maximumSpeed ?? 1_100 },
            set: { model.setLayerJoystickMaximumSpeed($0) }
        )
    }
}
