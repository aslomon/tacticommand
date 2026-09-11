import CreatorMicroCore
import SwiftUI

struct ActionSequenceOptionsView: View {
    let action: Binding<CreatorAction>
    let actions: [CreatorAction]

    var body: some View {
        InspectorSection(title: "SAFE ACTION SEQUENCE") {
            ForEach(Array(actions.indices), id: \.self) { index in
                stepRow(index: index)
            }
            Button {
                appendStep()
            } label: {
                Label("Add Step", systemImage: "plus")
            }
            .disabled(actions.count >= 6)
            Text(
                "Runs 2–6 safe built-in actions in order. Scripts, dictation, layers, and nested sequences are excluded."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func stepRow(index: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Picker("Step \(index + 1)", selection: stepBinding(index: index)) {
                ForEach(ActionSequenceStepKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.symbol).tag(kind)
                }
            }
            .labelsHidden()
            Button {
                removeStep(at: index)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .disabled(actions.count <= 2)
            .help("Remove step")
        }
    }

    private func stepBinding(index: Int) -> Binding<ActionSequenceStepKind> {
        Binding(
            get: {
                guard case .actionSequence(let current) = action.wrappedValue,
                    current.indices.contains(index)
                else {
                    return .copy
                }
                return ActionSequenceStepKind(action: current[index]) ?? .copy
            },
            set: { kind in replaceStep(at: index, with: kind.action) }
        )
    }

    private func replaceStep(at index: Int, with replacement: CreatorAction) {
        guard case .actionSequence(var current) = action.wrappedValue,
            current.indices.contains(index)
        else {
            return
        }
        current[index] = replacement
        action.wrappedValue = .actionSequence(current)
    }

    private func appendStep() {
        guard case .actionSequence(var current) = action.wrappedValue,
            current.count < 6
        else {
            return
        }
        current.append(.returnKey)
        action.wrappedValue = .actionSequence(current)
    }

    private func removeStep(at index: Int) {
        guard case .actionSequence(var current) = action.wrappedValue,
            current.count > 2,
            current.indices.contains(index)
        else {
            return
        }
        current.remove(at: index)
        action.wrappedValue = .actionSequence(current)
    }
}

private enum ActionSequenceStepKind: String, CaseIterable, Identifiable {
    case copy
    case paste
    case pastePlainText
    case returnKey
    case escapeKey
    case deleteKey
    case approval
    case volumeUp
    case volumeDown
    case outputMute
    case inputMute
    case openTerminal
    case openFinder
    case switchApplication
    case switchWindow

    var id: String { rawValue }

    var action: CreatorAction {
        switch self {
        case .copy: .copy
        case .paste: .paste
        case .pastePlainText: .pastePlainText
        case .returnKey: .returnKey
        case .escapeKey: .escapeKey
        case .deleteKey: .deleteKey
        case .approval: .approval
        case .volumeUp: .volume(.increase)
        case .volumeDown: .volume(.decrease)
        case .outputMute: .outputMute(.toggle)
        case .inputMute: .inputMute(.toggle)
        case .openTerminal: .openTerminal
        case .openFinder: .openFinder
        case .switchApplication: .switchApplication(.next)
        case .switchWindow: .switchWindow(.next)
        }
    }

    init?(action: CreatorAction) {
        switch action {
        case .copy: self = .copy
        case .paste: self = .paste
        case .pastePlainText: self = .pastePlainText
        case .returnKey: self = .returnKey
        case .escapeKey: self = .escapeKey
        case .deleteKey: self = .deleteKey
        case .approval: self = .approval
        case .volume(.increase): self = .volumeUp
        case .volume(.decrease): self = .volumeDown
        case .outputMute: self = .outputMute
        case .inputMute: self = .inputMute
        case .openTerminal: self = .openTerminal
        case .openFinder: self = .openFinder
        case .switchApplication: self = .switchApplication
        case .switchWindow: self = .switchWindow
        default: return nil
        }
    }

    var title: String { ActionKind(action: action).title }
    var symbol: String { ActionKind(action: action).symbol }
}
