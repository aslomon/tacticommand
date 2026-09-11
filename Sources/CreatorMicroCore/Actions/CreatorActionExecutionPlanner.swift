public enum CreatorActionExecutionPlan: Equatable, Sendable {
    case ignore
    case performOnce(CreatorAction)
    case beginDictation(DictationBinding)
    case endDictation(DictationBinding)
}

public struct CreatorActionExecutionPlanner: Sendable {
    public init() {}

    public func plan(_ event: RoutedCreatorAction) -> CreatorActionExecutionPlan {
        guard event.action != .none else { return .ignore }
        if case .dictation(let binding) = event.action {
            return dictationPlan(binding: binding, phase: event.phase)
        }
        return event.phase == .pressed ? .performOnce(event.action) : .ignore
    }

    private func dictationPlan(
        binding: DictationBinding,
        phase: ButtonPhase
    ) -> CreatorActionExecutionPlan {
        switch (binding.behavior, phase) {
        case (.toggle, .pressed): .performOnce(.dictation(binding))
        case (.toggle, .released): .ignore
        case (.holdToTalk, .pressed): .beginDictation(binding)
        case (.holdToTalk, .released): .endDictation(binding)
        }
    }
}
