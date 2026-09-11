import CreatorMicroCore
import SwiftUI

struct LayerTargetOptionsView: View {
    let model: AppModel
    let action: Binding<CreatorAction>
    let target: LayerIndex

    var body: some View {
        InspectorSection(title: "SOFTWARE LAYER") {
            Picker("Layer", selection: targetBinding) {
                ForEach(model.configuration.layers) { layer in
                    Text(layer.name).tag(layer.id)
                }
            }
            .labelsHidden()
            Text("Changes the app mapping only; the firmware has no set-layer command.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var targetBinding: Binding<LayerIndex> {
        Binding(
            get: { target },
            set: { action.wrappedValue = .layer(.select($0)) }
        )
    }
}
