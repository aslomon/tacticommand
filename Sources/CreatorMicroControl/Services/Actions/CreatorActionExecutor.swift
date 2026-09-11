import CreatorMicroCore

public enum CreatorActionExecutionFailure: Error, Equatable, Sendable {
    case event(SystemEventFailure)
    case workspace(WorkspaceApplicationFailure)
    case audio(SystemAudioFailure)
    case script(SafeScriptFailure)
    case shortcutRequired(DictationProviderID)
    case unsupportedDictationBehavior(
        providerID: DictationProviderID,
        behavior: DictationBehavior
    )
    case unsupportedAction(CreatorAction)
}

public enum CreatorActionExecutionSuccess: Equatable, Sendable {
    case completed
    case audioSnapshot(SystemAudioSnapshot)
}

@MainActor
public final class CreatorActionExecutor {
    private let planner: CreatorActionExecutionPlanner
    private let events: SystemEventSynthesizer
    private let workspace: WorkspaceApplicationController
    private let audio: any SystemAudioControlling
    private let serializedAudio: SerializedSystemAudioController
    private let scripts: SafeScriptRunner
    private let shortcutResolver: DictationShortcutResolver

    public init(
        planner: CreatorActionExecutionPlanner = CreatorActionExecutionPlanner(),
        events: SystemEventSynthesizer = SystemEventSynthesizer(),
        workspace: WorkspaceApplicationController = WorkspaceApplicationController(),
        audio: any SystemAudioControlling = SystemAudioController(),
        scripts: SafeScriptRunner = SafeScriptRunner(),
        shortcutResolver: DictationShortcutResolver = DictationShortcutResolver()
    ) {
        self.planner = planner
        self.events = events
        self.workspace = workspace
        self.audio = audio
        serializedAudio = SerializedSystemAudioController(controller: audio)
        self.scripts = scripts
        self.shortcutResolver = shortcutResolver
    }

    public func execute(
        _ event: RoutedCreatorAction
    ) async -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        switch planner.plan(event) {
        case .ignore:
            return .success(.completed)
        case .performOnce(let action):
            return await performOnce(action)
        case .beginDictation(let binding):
            return await performDictation(binding, phase: .pressed)
        case .endDictation(let binding):
            return await performDictation(binding, phase: .released)
        }
    }

    public func currentAudioSnapshot() -> SystemAudioSnapshot {
        audio.snapshot()
    }

    private func performOnce(
        _ action: CreatorAction
    ) async -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        switch action {
        case .none: .success(.completed)
        case .dictation(let binding): await performDictation(binding, phase: nil)
        case .approval, .returnKey, .escapeKey, .deleteKey, .copy, .paste,
            .pastePlainText, .keyboardShortcut:
            await performKeyboardAction(action)
        case .openTerminal: workspaceResult(await workspace.activateTerminal())
        case .openFinder: workspaceResult(await workspace.activateFinder())
        case .openApplication(let bundleIdentifier):
            workspaceResult(await workspace.activateApplication(bundleIdentifier: bundleIdentifier))
        case .switchApplication(let direction):
            eventResult(await events.switchApplication(direction))
        case .switchWindow(let direction):
            eventResult(await events.switchWindow(direction))
        case .layer, .shortOrLongPress, .actionSequence:
            .failure(.unsupportedAction(action))
        case .textSnippet(let text): eventResult(events.typeText(text))
        case .slashCommand(let command, let submit):
            await performSlashCommand(command, submit: submit)
        case .volume(let command): audioResult(await serializedAudio.applyVolume(command))
        case .outputMute(let command):
            audioResult(await serializedAudio.applyOutputMute(command))
        case .inputMute(let command): audioResult(await serializedAudio.applyInputMute(command))
        case .pointer(let command): eventResult(events.perform(command))
        case .appleScript(let source): scriptResult(await scripts.runAppleScript(source))
        case .shellCommand(let command): scriptResult(await scripts.runShellCommand(command))
        case .agentFocus, .focusNextAgent: .failure(.unsupportedAction(action))
        }
    }

    private func performDictation(
        _ binding: DictationBinding,
        phase: ButtonPhase?
    ) async -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        let shortcut: KeyShortcut
        switch shortcutResolver.shortcut(for: binding) {
        case .success(let resolvedShortcut):
            shortcut = resolvedShortcut
        case .failure(.shortcutRequired(let providerID)):
            return .failure(.shortcutRequired(providerID))
        case .failure(.unsupportedBehavior(let providerID, let behavior)):
            return .failure(
                .unsupportedDictationBehavior(
                    providerID: providerID,
                    behavior: behavior
                )
            )
        }
        if binding.providerID == .chatGPTCodex, phase != .released {
            let activation = await workspace.activateFirstAvailableApplication(
                bundleIdentifiers: BuiltInDictationProvider.chatGPTCodex.applicationBundleIdentifiers
            )
            if case .failure(let failure) = activation {
                return .failure(.workspace(failure))
            }
        }
        if let phase { return eventResult(events.send(shortcut, phase: phase)) }
        return eventResult(await events.tap(shortcut))
    }

    nonisolated static func keyboardShortcut(for action: CreatorAction) -> KeyShortcut? {
        switch action {
        case .approval, .returnKey: KeyShortcut(key: "return")
        case .escapeKey: KeyShortcut(key: "escape")
        case .deleteKey: KeyShortcut(key: "delete")
        case .copy: KeyShortcut(key: "c", modifiers: [.command])
        case .paste: KeyShortcut(key: "v", modifiers: [.command])
        case .pastePlainText:
            KeyShortcut(key: "v", modifiers: [.command, .option, .shift])
        case .keyboardShortcut(let shortcut): shortcut
        default: nil
        }
    }

    private func performSlashCommand(
        _ command: String,
        submit: Bool
    ) async -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        if case .failure(let failure) = events.typeText(command) {
            return .failure(.event(failure))
        }
        guard submit else { return .success(.completed) }
        return eventResult(await events.tap(KeyShortcut(key: "return")))
    }

    private func performKeyboardAction(
        _ action: CreatorAction
    ) async -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        guard let shortcut = Self.keyboardShortcut(for: action) else {
            return .failure(.unsupportedAction(action))
        }
        return eventResult(await events.tap(shortcut))
    }

    private func eventResult(
        _ result: Result<Void, SystemEventFailure>
    ) -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        result.map { .completed }.mapError(CreatorActionExecutionFailure.event)
    }

    private func workspaceResult(
        _ result: Result<Void, WorkspaceApplicationFailure>
    ) -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        result.map { .completed }.mapError(CreatorActionExecutionFailure.workspace)
    }

    private func audioResult(
        _ result: Result<SystemAudioSnapshot, SystemAudioFailure>
    ) -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        result.map { .audioSnapshot($0) }.mapError(CreatorActionExecutionFailure.audio)
    }

    private func scriptResult(
        _ result: Result<Void, SafeScriptFailure>
    ) -> Result<CreatorActionExecutionSuccess, CreatorActionExecutionFailure> {
        result.map { .completed }.mapError(CreatorActionExecutionFailure.script)
    }
}
