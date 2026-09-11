import CreatorMicroCore

extension AppModel {
    func consume(_ update: MicroCoordinatorUpdate) async {
        switch update {
        case .connection(let state):
            await applyConnectionState(state)
        case .event(let event):
            clearResolvedDeviceDiagnostic()
            if case .radial = event { return }
            await handle(event)
        case .diagnostic(let message):
            lastDeviceDiagnostic = message
            lastError = message
        }
    }

    func handle(_ event: MicroDeviceEvent) async {
        switch event {
        case .status(let status):
            apply(status)
        case .input(let input):
            await handle(input)
        case .radial(let radial):
            handle(radial)
        case .unhandled:
            break
        }
    }

    private func applyConnectionState(_ state: DeviceConnectionState) async {
        connectionState = state
        switch state {
        case .connected(_, let status):
            clearResolvedDeviceDiagnostic()
            refreshDeviceInventory()
            if let status { apply(status) }
            await synchronizeLighting()
        case .disconnected, .connecting, .unavailable:
            pressedControls.removeAll()
            let releases = resetActiveRoutedActions()
            for release in releases {
                await execute(release)
            }
        }
    }

    func refreshDeviceInventory() {
        detectedDevices = deviceInventory.connectedDevices()
        knownDevices = MicroDeviceInventoryPresentation.remembering(
            detectedDevices,
            among: knownDevices
        )
        recentDeviceStore.save(knownDevices)
    }

    private func clearResolvedDeviceDiagnostic() {
        if lastError == lastDeviceDiagnostic { lastError = nil }
        lastDeviceDiagnostic = nil
    }

    private func handle(_ input: MicroInputEvent) async {
        updatePressedControls(with: input)
        let routedActions = runtimeRouter.route(input, on: selectedLayer)
        let actions = resolvePressActions(routedActions, from: input)
        for action in actions {
            await execute(action)
        }
    }

    func execute(_ event: RoutedCreatorAction) async {
        switch await executeRoutedAction(event) {
        case .success:
            clearResolvedActionError()
        case .failure(let failure):
            lastError = failure.message
            applySystemAccess(accessController.snapshot())
        }
    }

    private func clearResolvedActionError() {
        guard lastError != lastDeviceDiagnostic else { return }
        lastError = nil
    }

    func executeRoutedAction(
        _ event: RoutedCreatorAction,
        layerSource: LayerSelectionSource = .physicalKey
    ) async -> Result<Void, LocalAutomationHandlerFailure> {
        if case .layer(let command) = event.action {
            guard event.phase == .pressed else { return .success(()) }
            apply(layer: command, source: layerSource)
            return .success(())
        }
        if case .agentFocus(let sessionID) = event.action {
            return await focusAgentResult(sessionID: sessionID, phase: event.phase)
        }
        if case .focusNextAgent = event.action {
            return await focusNextAgentResult(phase: event.phase)
        }
        if case .actionSequence(let actions) = event.action {
            return await executeSequence(actions, phase: event.phase)
        }
        switch await actionExecutor.execute(event) {
        case .success(let success):
            applySuccessfulAction(event, success: success)
            return .success(())
        case .failure(let failure):
            return .failure(LocalAutomationHandlerFailure(message: failure.userMessage))
        }
    }

    private func executeSequence(
        _ actions: [CreatorAction],
        phase: ButtonPhase
    ) async -> Result<Void, LocalAutomationHandlerFailure> {
        guard phase == .pressed else { return .success(()) }
        for action in actions {
            let result = await executeRoutedAction(
                RoutedCreatorAction(action: action, phase: .pressed)
            )
            if case .failure = result { return result }
        }
        return .success(())
    }

    private func apply(_ status: DeviceStatus) {
        deviceStatus = status
        layerSelection.observe(status: status)
    }

    func handle(_ radial: RadialInputEvent) {
        guard !isTerminating else {
            stopJoystickInput(invalidatePosition: true)
            return
        }
        guard let joystick = configuration.resolvedJoystick(for: activeLayer) else {
            stopJoystickInput()
            return
        }
        guard systemAccess.canControlSystem,
            SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess)
        else {
            stopJoystickInput(invalidatePosition: true)
            return
        }
        guard acceptJoystickInput(radial, deadZone: joystick.deadZone) else { return }
        switch joystick.mode {
        case .pointer:
            arrowKeyController.stop()
            guard let pointer = joystick.pointerConfiguration else { return }
            pointerController.update(radial, configuration: pointer)
        case .arrowKeys:
            pointerController.stop()
            arrowKeyController.update(radial, deadZone: joystick.deadZone)
        case .off:
            stopJoystickInput(requireNeutral: false)
        }
    }

    private func updatePressedControls(with input: MicroInputEvent) {
        switch input.phase {
        case .pressed: pressedControls.insert(input.control)
        case .released: pressedControls.remove(input.control)
        case .pulse: selectedControl = input.control
        }
    }

}
