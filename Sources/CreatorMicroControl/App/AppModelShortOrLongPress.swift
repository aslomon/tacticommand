import CreatorMicroCore

extension AppModel {
    func resolvePressActions(
        _ routedActions: [RoutedCreatorAction],
        from input: MicroInputEvent
    ) -> [RoutedCreatorAction] {
        let control = logicalPressControl(for: input.control)
        if shouldFinishTrackedPress(
            control: control,
            input: input,
            routedActions: routedActions
        ) {
            return finishTrackedPress(control: control)
        }
        var resolved: [RoutedCreatorAction] = []
        for event in routedActions {
            resolved += resolvePressAction(
                event,
                inputPhase: input.phase,
                control: control
            )
        }
        return resolved
    }

    func resetShortOrLongPresses() -> [RoutedCreatorAction] {
        for task in longPressTasks.values { task.cancel() }
        longPressTasks.removeAll()
        return emittedActions(from: shortOrLongPressState.reset())
    }

    func resetActiveRoutedActions() -> [RoutedCreatorAction] {
        let microphoneReleases = runtimeRouter.reset().filter { event in
            !event.action.isShortOrLongPress
        }
        return microphoneReleases + resetShortOrLongPresses()
    }

    func releaseShortOrLongPressesForLayerChange() {
        let releases = resetShortOrLongPresses()
        guard !releases.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            for release in releases { await execute(release) }
        }
    }

    private func resolvePressAction(
        _ event: RoutedCreatorAction,
        inputPhase: MicroInputPhase,
        control: ControlID
    ) -> [RoutedCreatorAction] {
        guard case .shortOrLongPress(let shortPress, let longPress) = event.action else {
            return [event]
        }
        switch inputPhase {
        case .pressed:
            return consume(
                shortOrLongPressState.begin(
                    control: control,
                    shortPress: shortPress,
                    longPress: longPress
                )
            )
        case .released:
            return finishTrackedPress(control: control)
        case .pulse:
            lastError = "Encoder rotations cannot use short and long press actions."
            return []
        }
    }

    private func finishTrackedPress(
        control: ControlID
    ) -> [RoutedCreatorAction] {
        longPressTasks.removeValue(forKey: control)?.cancel()
        return consume(shortOrLongPressState.release(control: control))
    }

    private func consume(
        _ effects: [ShortOrLongPressEffect]
    ) -> [RoutedCreatorAction] {
        var actions: [RoutedCreatorAction] = []
        for effect in effects {
            switch effect {
            case .schedule(let deadline): schedule(deadline)
            case .emit(let action): actions.append(action)
            }
        }
        return actions
    }

    private func schedule(_ deadline: ShortOrLongPressDeadline) {
        longPressTasks[deadline.control]?.cancel()
        longPressTasks[deadline.control] = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(deadline.delayMilliseconds))
            } catch {
                return
            }
            guard let self else { return }
            longPressTasks[deadline.control] = nil
            let actions = consume(shortOrLongPressState.thresholdReached(deadline))
            for action in actions { await execute(action) }
        }
    }

    private func emittedActions(
        from effects: [ShortOrLongPressEffect]
    ) -> [RoutedCreatorAction] {
        effects.compactMap { effect in
            guard case .emit(let action) = effect else { return nil }
            return action
        }
    }

    private func logicalPressControl(for control: ControlID) -> ControlID {
        guard configuration.microphoneLayout == .linked,
            control == .action10 || control == .action11
        else {
            return control
        }
        return .action10
    }

    private func shouldFinishTrackedPress(
        control: ControlID,
        input: MicroInputEvent,
        routedActions: [RoutedCreatorAction]
    ) -> Bool {
        guard input.phase == .released,
            shortOrLongPressState.isTracking(control)
        else {
            return false
        }
        guard configuration.microphoneLayout == .linked,
            input.control == .action10 || input.control == .action11
        else {
            return true
        }
        return routedActions.contains { event in
            event.phase == .released && event.action.isShortOrLongPress
        }
    }
}

extension CreatorAction {
    fileprivate var isShortOrLongPress: Bool {
        if case .shortOrLongPress = self { return true }
        return false
    }
}
