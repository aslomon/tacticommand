import CreatorMicroCore

extension AppModel {
    func testDictationShortcut(
        _ binding: DictationBinding
    ) async -> Result<Void, LocalAutomationHandlerFailure> {
        let planner = DictationTestGesturePlanner()
        var cancellationFailure: LocalAutomationHandlerFailure?
        for step in planner.steps(for: binding) {
            switch step {
            case .send(let phase):
                let event = RoutedCreatorAction(
                    action: .dictation(binding),
                    phase: phase
                )
                if case .failure(let failure) = await executeRoutedAction(event) {
                    return .failure(failure)
                }
            case .wait(let milliseconds):
                do {
                    try await Task.sleep(for: .milliseconds(milliseconds))
                } catch {
                    cancellationFailure = LocalAutomationHandlerFailure(
                        message: "Shortcut test was cancelled after releasing the held key."
                    )
                }
            }
        }
        if let cancellationFailure {
            return .failure(cancellationFailure)
        }
        return .success(())
    }
}
