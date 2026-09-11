import CreatorMicroCore
import SwiftUI

enum ShortOrLongPressBindingEditor {
    static func shortPress(in action: CreatorAction) -> CreatorAction {
        guard case .shortOrLongPress(let shortPress, _) = action else {
            return action
        }
        return shortPress
    }

    static func longPress(in action: CreatorAction) -> CreatorAction? {
        guard case .shortOrLongPress(_, let longPress) = action else {
            return nil
        }
        return longPress
    }

    static func replacingShortPress(
        in action: CreatorAction,
        with shortPress: CreatorAction
    ) -> CreatorAction {
        guard isLeaf(shortPress) else { return action }
        guard shortPress != .none,
            let longPress = longPress(in: action)
        else {
            return shortPress
        }
        return .shortOrLongPress(
            shortPress: shortPress,
            longPress: longPress
        )
    }

    static func replacingLongPress(
        in action: CreatorAction,
        with longPress: CreatorAction?
    ) -> CreatorAction {
        guard longPress.map(isLeaf) ?? true else { return action }
        let shortPress = shortPress(in: action)
        guard shortPress != .none,
            let longPress,
            longPress != .none
        else {
            return shortPress
        }
        return .shortOrLongPress(
            shortPress: shortPress,
            longPress: longPress
        )
    }

    private static func isLeaf(_ action: CreatorAction) -> Bool {
        if case .shortOrLongPress = action { return false }
        return true
    }
}

struct ActionBindingPickerView: View {
    let model: AppModel

    var body: some View {
        InspectorSection(title: "ACTION") {
            if model.selectedControl.isEncoderRotation {
                actionPicker("Action", selection: shortKind)
                    .labelsHidden()
            } else {
                actionPicker("Short press", selection: shortKind)
                actionPicker("Long press (optional)", selection: longKind)
                Text("Long press starts after 450 ms. Release ends its held action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionPicker(
        _ title: String,
        selection: Binding<ActionKind>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(ActionKind.allCases) { kind in
                Label(kind.title, systemImage: kind.symbol).tag(kind)
            }
        }
    }

    private var shortKind: Binding<ActionKind> {
        Binding(
            get: { ActionKind(action: shortPress) },
            set: { kind in
                let replacement = kind.makeAction(current: shortPress)
                model.assign(
                    ShortOrLongPressBindingEditor.replacingShortPress(
                        in: model.selectedAction,
                        with: replacement
                    )
                )
            }
        )
    }

    private var longKind: Binding<ActionKind> {
        Binding(
            get: { longPress.map(ActionKind.init) ?? .none },
            set: { kind in
                let replacement =
                    kind == .none
                    ? nil
                    : kind.makeAction(current: longPress ?? .none)
                model.assign(
                    ShortOrLongPressBindingEditor.replacingLongPress(
                        in: model.selectedAction,
                        with: replacement
                    )
                )
            }
        )
    }

    private var shortPress: CreatorAction {
        ShortOrLongPressBindingEditor.shortPress(in: model.selectedAction)
    }

    private var longPress: CreatorAction? {
        ShortOrLongPressBindingEditor.longPress(in: model.selectedAction)
    }
}

struct ActionBranchOptionsView: View {
    let model: AppModel

    var body: some View {
        if model.selectedControl.isEncoderRotation {
            ActionOptionsView(model: model, action: selectedActionBinding)
        } else if hasLongPress {
            branchOptions(title: "SHORT PRESS OPTIONS", action: shortPressBinding)
            branchOptions(title: "LONG PRESS OPTIONS", action: longPressBinding)
        } else {
            ActionOptionsView(model: model, action: shortPressBinding)
        }
    }

    @ViewBuilder
    private func branchOptions(
        title: String,
        action: Binding<CreatorAction>
    ) -> some View {
        if ActionOptionsView.supports(action.wrappedValue) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                ActionOptionsView(model: model, action: action)
            }
        }
    }

    private var selectedActionBinding: Binding<CreatorAction> {
        Binding(
            get: { model.selectedAction },
            set: { model.assign($0) }
        )
    }

    private var shortPressBinding: Binding<CreatorAction> {
        Binding(
            get: { ShortOrLongPressBindingEditor.shortPress(in: model.selectedAction) },
            set: { replacement in
                model.assign(
                    ShortOrLongPressBindingEditor.replacingShortPress(
                        in: model.selectedAction,
                        with: replacement
                    )
                )
            }
        )
    }

    private var longPressBinding: Binding<CreatorAction> {
        Binding(
            get: {
                ShortOrLongPressBindingEditor.longPress(in: model.selectedAction) ?? .none
            },
            set: { replacement in
                model.assign(
                    ShortOrLongPressBindingEditor.replacingLongPress(
                        in: model.selectedAction,
                        with: replacement
                    )
                )
            }
        )
    }

    private var hasLongPress: Bool {
        ShortOrLongPressBindingEditor.longPress(in: model.selectedAction) != nil
    }
}
