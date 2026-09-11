import CreatorMicroCore
import SwiftUI

struct LayerRailView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAYERS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 16)

            ForEach(model.configuration.layers) { layer in
                Button {
                    withAnimation(.spring(duration: 0.22, bounce: 0.08)) {
                        model.select(layer: layer.id)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("\(layer.id.rawValue + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .frame(width: 22, height: 22)
                            .background(layerColor(layer.id).opacity(0.16), in: Circle())
                        Text(layer.name)
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(
                        model.activeLayer == layer.id ? Color.primary : Color.secondary
                    )
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(
                        model.activeLayer == layer.id
                            ? DesignTokens.signal.opacity(0.12)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 6)
            }

            Divider()
                .padding(.horizontal, 12)
                .padding(.top, 4)
            selectionStatus
            Divider()
                .padding(.horizontal, 12)
            applicationRulePicker

            Spacer()
            VStack(alignment: .leading, spacing: 5) {
                Label("Physical host control", systemImage: "hand.tap")
                    .font(.caption)
                Text(LayerSelectionPresentation.physicalControlExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .background(Color.primary.opacity(0.025))
    }

    private var selectionStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(presentation.status, systemImage: statusSymbol)
                .font(.caption)
                .foregroundStyle(DesignTokens.signal)
            Text(presentation.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let observation = presentation.firmwareObservation {
                Text(observation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
    }

    private var applicationRulePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AUTO LAYER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Picker("Application", selection: applicationRuleBinding) {
                Text("Manual only").tag("")
                ForEach(model.installedApplicationChoices) { application in
                    Text(application.name).tag(application.bundleIdentifier)
                }
            }
            .labelsHidden()
            Text("Temporarily switches while this app is frontmost.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
    }

    private var applicationRuleBinding: Binding<String> {
        Binding(
            get: { model.applicationRule(for: model.activeLayer) ?? "" },
            set: { identifier in
                model.setApplicationRule(
                    bundleIdentifier: identifier.isEmpty ? nil : identifier,
                    for: model.activeLayer
                )
            }
        )
    }

    private func layerColor(_ layer: LayerIndex) -> Color {
        model.activeLayer == layer ? DesignTokens.signal : .secondary
    }

    private var presentation: LayerSelectionPresentation {
        LayerSelectionPresentation(
            state: model.layerSelection,
            layerName: model.selectedLayer.name
        )
    }

    private var statusSymbol: String {
        "macwindow"
    }
}
