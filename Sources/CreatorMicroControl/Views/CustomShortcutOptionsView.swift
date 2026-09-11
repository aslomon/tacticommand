import CreatorMicroCore
import SwiftUI

struct CustomShortcutOptionsView: View {
    let action: Binding<CreatorAction>

    var body: some View {
        InspectorSection(title: "KEYBOARD SHORTCUT") {
            LabeledContent("Name") {
                TextField("Open command palette", text: displayNameBinding)
                    .textFieldStyle(.roundedBorder)
            }
            Text("Optional. This name is shown on the assigned key and in the inspector.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ShortcutEditorView(shortcut: shortcutBinding)
            Text("Records and sends the exact shortcut once when the Micro key is pressed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutBinding: Binding<KeyShortcut?> {
        Binding(
            get: {
                guard case .keyboardShortcut(let shortcut) = action.wrappedValue else {
                    return nil
                }
                return shortcut
            },
            set: { shortcut in
                action.wrappedValue = shortcut.map(CreatorAction.keyboardShortcut) ?? .none
            }
        )
    }

    private var displayNameBinding: Binding<String> {
        Binding(
            get: { shortcutBinding.wrappedValue?.displayName ?? "" },
            set: { displayName in
                guard let shortcut = shortcutBinding.wrappedValue else { return }
                shortcutBinding.wrappedValue = shortcut.renamed(to: displayName)
            }
        )
    }
}
