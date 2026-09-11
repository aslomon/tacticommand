import CreatorMicroCore
import SwiftUI

struct LayerPresetControlsView: View {
    let model: AppModel

    @State private var draftName = ""
    @State private var editingLayer: LayerIndex?
    @State private var pendingSelection: PendingLayerPreset?
    @FocusState private var isEditingName: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECTED LAYER")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            layerNameControl
            Menu {
                ForEach(MicroLayerPresetCatalog.all) { preset in
                    Button(preset.name) {
                        pendingSelection = PendingLayerPreset(
                            preset: preset,
                            target: model.activeLayer
                        )
                    }
                    .help(preset.detail)
                }
            } label: {
                Label("Apply Workflow Preset", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            Text("Presets replace this slot and reuse your Desktop controls.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .onAppear {
            synchronizeName()
        }
        .onChange(of: model.activeLayer) { previousLayer, _ in
            if LayerNameEditingPolicy.shouldCommitOnLayerChange(isEditing: editingLayer != nil) {
                commitName(for: previousLayer)
            }
            editingLayer = nil
            isEditingName = false
            synchronizeName()
        }
        .onChange(of: model.selectedLayer.name) {
            if !isEditingName { synchronizeName() }
        }
        .onChange(of: model.isReady) {
            if !isEditingName { synchronizeName() }
        }
        .onChange(of: isEditingName) { wasEditing, isEditing in
            if wasEditing, !isEditing, let editingLayer {
                commitName(for: editingLayer)
                self.editingLayer = nil
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: confirmationBinding,
            titleVisibility: .visible
        ) {
            if let pendingSelection {
                Button("Apply \(pendingSelection.preset.name)", role: .destructive) {
                    model.applyPreset(
                        pendingSelection.preset.id,
                        to: pendingSelection.target
                    )
                    synchronizeName()
                    self.pendingSelection = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingSelection = nil
            }
        } message: {
            Text("The current bindings in the selected slot will be replaced.")
        }
    }

    @ViewBuilder
    private var layerNameControl: some View {
        if editingLayer != nil {
            TextField("Layer name", text: $draftName)
                .textFieldStyle(.roundedBorder)
                .focused($isEditingName)
                .onSubmit { finishRenaming() }
        } else {
            Button(action: beginRenaming) {
                HStack {
                    Text(draftName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "pencil")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Rename layer \(draftName)")
        }
    }

    private var confirmationTitle: String {
        guard let pendingSelection else { return "Apply Workflow Preset?" }
        let targetName = model.configuration.layer(pendingSelection.target)?.name ?? "layer"
        return "Replace \(targetName) with \(pendingSelection.preset.name)?"
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingSelection != nil },
            set: { isPresented in
                if !isPresented { pendingSelection = nil }
            }
        )
    }

    private func synchronizeName() {
        draftName = model.selectedLayer.name
    }

    private func commitName(for layer: LayerIndex? = nil) {
        model.renameLayer(draftName, layer: layer)
        synchronizeName()
    }

    private func beginRenaming() {
        editingLayer = model.activeLayer
        Task { @MainActor in
            await Task.yield()
            guard editingLayer != nil else { return }
            isEditingName = true
        }
    }

    private func finishRenaming() {
        guard let editingLayer else { return }
        commitName(for: editingLayer)
        self.editingLayer = nil
        isEditingName = false
    }
}

private struct PendingLayerPreset {
    let preset: MicroLayerPreset
    let target: LayerIndex
}

enum LayerNameEditingPolicy {
    static func shouldCommitOnLayerChange(isEditing: Bool) -> Bool {
        isEditing
    }
}
