import AppIntents
import CreatorMicroCore

struct CreatorMicroStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Creator Micro Status"
    static let description = IntentDescription(
        "Returns the active layer and local hardware connection state."
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await LocalAutomationClient().call(.status)
        return .result(dialog: statusDialog(for: result))
    }

    private func statusDialog(
        for result: Result<LocalAutomationResult, LocalAutomationClientFailure>
    ) -> IntentDialog {
        switch result {
        case .success(.status(let status)):
            return "Creator Micro is on layer \(status.activeLayer.rawValue + 1) and is \(status.connection.rawValue)."
        case .success:
            return "Creator Micro returned an unexpected status response."
        case .failure(let failure):
            return IntentDialog(failure.message)
        }
    }
}

struct CreatorMicroSetLayerIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Creator Micro Layer"
    static let description = IntentDescription("Selects one of the six Creator Micro layers.")
    static let openAppWhenRun = true

    @Parameter(title: "Layer")
    var layer: CreatorMicroLayerIntentValue

    static var parameterSummary: some ParameterSummary {
        Summary("Set Creator Micro to \(\.$layer)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let result = await LocalAutomationClient().call(.setLayer(layer.layer))
        return .result(dialog: result.dialog(success: "Creator Micro layer changed."))
    }
}

struct CreatorMicroTriggerBindingIntent: AppIntent {
    static let title: LocalizedStringResource = "Trigger Creator Micro Binding"
    static let description = IntentDescription(
        "Triggers a configured binding. Shell commands and AppleScript are always blocked."
    )
    static let openAppWhenRun = true

    @Parameter(title: "Control")
    var control: CreatorMicroControlIntentValue

    @Parameter(title: "Layer")
    var layer: CreatorMicroLayerIntentValue

    static var parameterSummary: some ParameterSummary {
        Summary("Trigger \(\.$control) on \(\.$layer)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let command = LocalAutomationCommand.triggerBinding(
            control: control.control,
            layer: layer.layer
        )
        let result = await LocalAutomationClient().call(command)
        return .result(dialog: result.dialog(success: "Creator Micro binding triggered."))
    }
}

struct CreatorMicroShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreatorMicroStatusIntent(),
            phrases: ["Get \(.applicationName) status"],
            shortTitle: "Creator Micro Status",
            systemImageName: "keyboard.badge.ellipsis"
        )
        AppShortcut(
            intent: CreatorMicroSetLayerIntent(),
            phrases: ["Set \(\.$layer) on \(.applicationName)"],
            shortTitle: "Set Micro Layer",
            systemImageName: "square.stack.3d.up"
        )
        AppShortcut(
            intent: CreatorMicroTriggerBindingIntent(),
            phrases: ["Trigger \(\.$control) with \(.applicationName)"],
            shortTitle: "Trigger Micro Binding",
            systemImageName: "button.programmable"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}

extension Result where Success == LocalAutomationResult, Failure == LocalAutomationClientFailure {
    fileprivate func dialog(success: LocalizedStringResource) -> IntentDialog {
        switch self {
        case .success: IntentDialog(success)
        case .failure(let failure): IntentDialog(failure.message)
        }
    }
}

extension LocalAutomationClientFailure {
    fileprivate var message: LocalizedStringResource {
        switch self {
        case .encoding:
            "Creator Micro could not encode the automation request."
        case .connection:
            "TactiCommand is not ready yet."
        case .transport:
            "TactiCommand did not answer."
        case .invalidResponse:
            "TactiCommand returned an invalid response."
        case .remote(let error):
            "TactiCommand rejected the request: \(error.message)"
        }
    }
}
