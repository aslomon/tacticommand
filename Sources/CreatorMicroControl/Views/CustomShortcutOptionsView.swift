import CreatorMicroCore
import SwiftUI

struct CustomShortcutOptionsView: View {
    let action: Binding<CreatorAction>

    var body: some View {
        InspectorSection(title: "KEYBOARD SHORTCUT") {
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
}
