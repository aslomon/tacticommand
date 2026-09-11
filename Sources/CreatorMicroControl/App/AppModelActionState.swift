import CreatorMicroCore

extension AppModel {
    func applySuccessfulAction(
        _ event: RoutedCreatorAction,
        success: CreatorActionExecutionSuccess
    ) {
        if case .audioSnapshot(let snapshot) = success {
            applyAudioSnapshot(snapshot)
            return
        }
        guard case .dictation(let binding) = event.action else { return }
        updateDictationState(binding: binding, phase: event.phase)
        Task { await synchronizeLighting() }
    }

    func focusAgent(sessionID: String, phase: ButtonPhase) async {
        if case .failure(let failure) = await focusAgentResult(
            sessionID: sessionID,
            phase: phase
        ) {
            lastError = failure.message
        }
    }

    func focusAgentResult(
        sessionID: String,
        phase: ButtonPhase
    ) async -> Result<Void, LocalAutomationHandlerFailure> {
        guard phase == .pressed else { return .success(()) }
        guard let slot = agentSlotID(from: sessionID) else {
            return .failure(
                LocalAutomationHandlerFailure(message: "The configured agent slot is invalid.")
            )
        }
        switch await agentStore.focus(slot: slot) {
        case .focused:
            return .success(())
        case .unavailable(let reason):
            return .failure(LocalAutomationHandlerFailure(message: reason.userMessage))
        }
    }

    func focusNextAgentResult(
        phase: ButtonPhase
    ) async -> Result<Void, LocalAutomationHandlerFailure> {
        guard phase == .pressed else { return .success(()) }
        guard let slot = AgentAttentionSelector.nextSlot(in: agentSnapshot) else {
            return .failure(
                LocalAutomationHandlerFailure(
                    message: "No agent currently needs attention."
                )
            )
        }
        return await focusAgentResult(
            sessionID: "slot-\(slot.rawValue + 1)",
            phase: phase
        )
    }

    private func updateDictationState(
        binding: DictationBinding,
        phase: ButtonPhase
    ) {
        switch binding.behavior {
        case .toggle where phase == .pressed:
            isDictating.toggle()
        case .holdToTalk:
            isDictating = phase == .pressed
        default:
            break
        }
    }

    private func agentSlotID(from sessionID: String) -> AgentSlotID? {
        guard sessionID.hasPrefix("slot-"),
            let number = Int(sessionID.dropFirst(5))
        else {
            return nil
        }
        return AgentSlotID(rawValue: number - 1)
    }
}
