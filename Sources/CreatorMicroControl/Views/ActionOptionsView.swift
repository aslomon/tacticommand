import CreatorMicroCore
import SwiftUI

struct ActionOptionsView: View {
    let model: AppModel
    let action: Binding<CreatorAction>

    var body: some View {
        actionOptions
    }

    static func supports(_ action: CreatorAction) -> Bool {
        switch action {
        case .dictation,
            .textSnippet,
            .keyboardShortcut,
            .slashCommand,
            .actionSequence,
            .appleScript,
            .shellCommand,
            .openApplication,
            .switchApplication,
            .switchWindow,
            .layer(.next),
            .layer(.previous),
            .layer(.select),
            .outputMute,
            .inputMute,
            .volume(.set),
            .pointer(.move),
            .agentFocus:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private var actionOptions: some View {
        switch action.wrappedValue {
        case .dictation(let binding):
            DictationOptionsView(model: model, action: action, binding: binding)
        case .textSnippet:
            textEditor(title: "TEXT", prompt: "Text to type")
        case .keyboardShortcut:
            CustomShortcutOptionsView(action: action)
        case .slashCommand:
            slashCommandOptions
        case .actionSequence(let actions):
            ActionSequenceOptionsView(action: action, actions: actions)
        case .appleScript:
            textEditor(title: "APPLESCRIPT", prompt: "tell application ...")
        case .shellCommand:
            textEditor(title: "SHELL COMMAND", prompt: "Command")
        case .openApplication:
            applicationOptions
        case .switchApplication:
            directionOptions(isWindow: false)
        case .switchWindow:
            directionOptions(isWindow: true)
        case .layer(.next):
            layerNavigationHelp(command: .next)
        case .layer(.previous):
            layerNavigationHelp(command: .previous)
        case .layer(.select(let layer)):
            LayerTargetOptionsView(model: model, action: action, target: layer)
        case .outputMute:
            muteOptions(isInput: false)
        case .inputMute:
            muteOptions(isInput: true)
        case .volume(.set(let value)):
            volumeOptions(value)
        case .pointer(.move(let horizontal, let vertical)):
            PointerMoveOptionsView(
                action: action,
                horizontal: horizontal,
                vertical: vertical
            )
        case .agentFocus:
            agentOptions
        default:
            EmptyView()
        }
    }

    private var applicationOptions: some View {
        InspectorSection(title: "APPLICATION") {
            Picker("Installed application", selection: associatedText) {
                Text("Choose an application").tag("")
                ForEach(applicationChoices, id: \.bundleIdentifier) { application in
                    Text(application.name).tag(application.bundleIdentifier)
                }
            }
            .labelsHidden()
            TextField("Bundle identifier", text: associatedText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func directionOptions(isWindow: Bool) -> some View {
        InspectorSection(title: "DIRECTION") {
            Picker("Direction", selection: directionBinding(isWindow: isWindow)) {
                Text("Next").tag(AppSwitchDirection.next)
                Text("Previous").tag(AppSwitchDirection.previous)
            }
            .pickerStyle(.segmented)
        }
    }

    private func layerNavigationHelp(command: LayerCommand) -> some View {
        let destination = command.destination(from: model.activeLayer)
        let destinationName =
            model.configuration.layer(destination)?.name
            ?? "Layer \(destination.displayPosition)"
        let actionLabel = command == .next ? "Next press" : "Previous press"
        return InspectorSection(title: "LAYER CHANGE") {
            Label("\(actionLabel): \(destinationName)", systemImage: "square.3.layers.3d")
                .font(.system(size: 12, weight: .medium))
            Text("Next and Previous move through all configured layers and wrap at either end.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func muteOptions(isInput: Bool) -> some View {
        InspectorSection(title: "MUTE BEHAVIOR") {
            Picker("Mute behavior", selection: muteBinding(isInput: isInput)) {
                Text("Toggle").tag(MuteCommand.toggle)
                Text("Mute").tag(MuteCommand.mute)
                Text("Unmute").tag(MuteCommand.unmute)
            }
            .pickerStyle(.segmented)
        }
    }

    private func volumeOptions(_ value: Double) -> some View {
        InspectorSection(title: "OUTPUT VOLUME") {
            HStack {
                Slider(value: volumeBinding, in: 0...1)
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 38, alignment: .trailing)
            }
        }
    }

    private func textEditor(title: String, prompt: String) -> some View {
        InspectorSection(title: title) {
            TextEditor(text: associatedText)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 88)
                .padding(6)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if associatedText.wrappedValue.isEmpty {
                        textEditorPrompt(prompt)
                    }
                }
        }
    }

    private var slashCommandOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            textEditor(title: "SLASH COMMAND", prompt: "/review")
            InspectorSection(title: "COMMAND BEHAVIOR") {
                Toggle("Submit with Return", isOn: slashCommandSubmit)
                Text("Types the command into Codex, Claude, or the focused text field.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func textEditorPrompt(_ prompt: String) -> some View {
        Text(prompt)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(10)
            .allowsHitTesting(false)
    }

    private var agentOptions: some View {
        InspectorSection(title: "AGENT SLOT") {
            Picker("Slot", selection: agentSlotBinding) {
                ForEach(1...6, id: \.self) { slot in
                    Text("Agent \(slot)").tag(slot)
                }
            }
            .labelsHidden()
        }
    }

    private var associatedText: Binding<String> {
        Binding(
            get: {
                switch action.wrappedValue {
                case .textSnippet(let value),
                    .slashCommand(let value, _),
                    .appleScript(let value),
                    .shellCommand(let value):
                    value
                case .openApplication(let bundleIdentifier): bundleIdentifier
                default: ""
                }
            },
            set: { value in replaceAssociatedText(with: value) }
        )
    }

    private func replaceAssociatedText(with value: String) {
        switch action.wrappedValue {
        case .textSnippet: action.wrappedValue = .textSnippet(value)
        case .slashCommand(_, let submit):
            action.wrappedValue = .slashCommand(command: value, submit: submit)
        case .appleScript: action.wrappedValue = .appleScript(value)
        case .shellCommand: action.wrappedValue = .shellCommand(value)
        case .openApplication: action.wrappedValue = .openApplication(bundleIdentifier: value)
        default: break
        }
    }

    private var slashCommandSubmit: Binding<Bool> {
        Binding(
            get: {
                guard case .slashCommand(_, let submit) = action.wrappedValue else {
                    return false
                }
                return submit
            },
            set: { submit in
                action.wrappedValue = .slashCommand(
                    command: associatedText.wrappedValue,
                    submit: submit
                )
            }
        )
    }

    private var agentSlotBinding: Binding<Int> {
        Binding(
            get: {
                guard case .agentFocus(let sessionID) = action.wrappedValue,
                    let slot = Int(sessionID.replacingOccurrences(of: "slot-", with: ""))
                else {
                    return 1
                }
                return slot
            },
            set: { action.wrappedValue = .agentFocus(sessionID: "slot-\($0)") }
        )
    }

    private var applicationChoices: [(bundleIdentifier: String, name: String)] {
        model.installedApplicationChoices.map { ($0.bundleIdentifier, $0.name) }
    }

    private func directionBinding(isWindow: Bool) -> Binding<AppSwitchDirection> {
        Binding(
            get: {
                switch action.wrappedValue {
                case .switchApplication(let value), .switchWindow(let value): value
                default: .next
                }
            },
            set: { direction in
                action.wrappedValue =
                    isWindow
                    ? .switchWindow(direction)
                    : .switchApplication(direction)
            }
        )
    }

    private func muteBinding(isInput: Bool) -> Binding<MuteCommand> {
        Binding(
            get: {
                switch action.wrappedValue {
                case .inputMute(let value), .outputMute(let value): value
                default: .toggle
                }
            },
            set: { command in
                action.wrappedValue = isInput ? .inputMute(command) : .outputMute(command)
            }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: {
                guard case .volume(.set(let value)) = action.wrappedValue else { return 0.5 }
                return value
            },
            set: { action.wrappedValue = .volume(.set($0)) }
        )
    }
}
