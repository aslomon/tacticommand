import CreatorMicroCore

extension AppModel {
    var selectedLayerJoystickOverride: LayerJoystickConfiguration? {
        configuration.layer(activeLayer)?.joystick
    }

    func setLayerJoystickOverrideEnabled(_ isEnabled: Bool) {
        let override =
            isEnabled
            ? LayerJoystickConfiguration(inheriting: configuration.joystick)
            : nil
        storeLayerJoystick(override)
    }

    func setLayerJoystickMode(_ mode: JoystickMode) {
        updateLayerJoystick { $0.mode = mode }
    }

    func setLayerJoystickDeadZone(_ deadZone: Double) {
        updateLayerJoystick { $0.deadZone = deadZone }
    }

    func setLayerJoystickMaximumSpeed(_ maximumSpeed: Double) {
        updateLayerJoystick { $0.maximumSpeed = maximumSpeed }
    }

    private func updateLayerJoystick(
        _ update: (inout LayerJoystickConfiguration) -> Void
    ) {
        guard var override = selectedLayerJoystickOverride else { return }
        update(&override)
        storeLayerJoystick(override)
    }

    private func storeLayerJoystick(_ override: LayerJoystickConfiguration?) {
        guard canMutateConfiguration else { return }
        resetJoystickLocalBoundary()
        configuration.setJoystick(override, on: activeLayer)
        saveConfiguration()
    }

    func resetJoystickLocalBoundary(restartRadial: Bool = true) {
        stopJoystickInput(invalidatePosition: true)
        joystickRadialGeneration &+= 1
        let generation = joystickRadialGeneration
        joystickRuntimeTask?.cancel()
        joystickRuntimeTask = nil
        joystickRadialRestartTask?.cancel()
        joystickRadialRestartTask = nil
        guard restartRadial, canRestartJoystickRadialRuntime else { return }
        joystickRadialRestartTask = Task { [weak self] in
            guard let self else { return }
            let updates = await coordinator.makeRadialUpdateStream()
            guard !Task.isCancelled,
                generation == joystickRadialGeneration,
                !isTerminating
            else { return }
            installJoystickRadialRuntime(updates, generation: generation)
            if generation == joystickRadialGeneration {
                joystickRadialRestartTask = nil
            }
        }
    }

    func stopJoystickInput(
        requireNeutral: Bool = true,
        invalidatePosition: Bool = false
    ) {
        if invalidatePosition { lastRadialInput = nil }
        let hasActiveInput = pointerController.isRunning || arrowKeyController.activeKey != nil
        let hasKnownCenter = lastRadialInput.map(isJoystickCentered) ?? false
        let shouldRequireNeutral =
            joystickRequiresNeutral || hasActiveInput
            || (requireNeutral && (invalidatePosition || !hasKnownCenter))
        pointerController.stop()
        arrowKeyController.stop(requireNeutral: shouldRequireNeutral)
        joystickRequiresNeutral = shouldRequireNeutral
    }

    func prepareForTermination() {
        isTerminating = true
        joystickRadialGeneration &+= 1
        runtimeTask?.cancel()
        joystickRuntimeTask?.cancel()
        joystickRadialRestartTask?.cancel()
        joystickSafetyRuntimeTask?.cancel()
        stopJoystickInput(invalidatePosition: true)
    }

    func acceptJoystickInput(
        _ sample: RadialInputEvent,
        deadZone: Double
    ) -> Bool {
        lastRadialInput = sample
        guard joystickRequiresNeutral else { return true }
        guard isJoystickCentered(sample, deadZone: deadZone) else { return false }
        arrowKeyController.update(sample, deadZone: deadZone)
        joystickRequiresNeutral = false
        return false
    }

    private func isJoystickCentered(_ sample: RadialInputEvent) -> Bool {
        let deadZone =
            configuration.resolvedJoystick(for: activeLayer)?.deadZone
            ?? configuration.joystick.deadZone
        return isJoystickCentered(sample, deadZone: deadZone)
    }

    private func isJoystickCentered(
        _ sample: RadialInputEvent,
        deadZone: Double
    ) -> Bool {
        sample.distance.isFinite && sample.distance <= deadZone
    }

    func startJoystickRuntime(
        radialUpdates: AsyncStream<SequencedRadialUpdate>,
        safetyUpdates: AsyncStream<SequencedConnectionUpdate>
    ) {
        guard !isTerminating else { return }
        joystickConnectionSequence = nil
        isJoystickConnectionVerified = false
        joystickRadialRestartTask?.cancel()
        joystickRadialRestartTask = nil
        joystickRadialGeneration &+= 1
        let radialGeneration = joystickRadialGeneration
        joystickRuntimeTask?.cancel()
        joystickSafetyRuntimeTask?.cancel()
        installJoystickRadialRuntime(radialUpdates, generation: radialGeneration)
        joystickSafetyRuntimeTask = Task { [weak self] in
            guard let self else { return }
            for await update in safetyUpdates {
                guard !Task.isCancelled else { break }
                handleJoystickSafety(update)
            }
        }
    }

    private var canRestartJoystickRadialRuntime: Bool {
        !isTerminating && runtimeTask != nil && systemAccess.canControlSystem
            && SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess)
    }

    private func installJoystickRadialRuntime(
        _ updates: AsyncStream<SequencedRadialUpdate>,
        generation: UInt64
    ) {
        joystickRuntimeTask = Task { [weak self] in
            guard let self else { return }
            for await update in updates {
                guard !Task.isCancelled else { break }
                guard generation == joystickRadialGeneration else { break }
                handleJoystickRadial(update, generation: generation)
            }
        }
    }

    func handleJoystickRadial(
        _ update: SequencedRadialUpdate,
        generation: UInt64
    ) {
        guard generation == joystickRadialGeneration else { return }
        handleJoystickRadial(update)
    }

    func handleJoystickRadial(_ update: SequencedRadialUpdate) {
        guard isJoystickConnectionVerified,
            let connectionSequence = joystickConnectionSequence,
            update.connectionSequence == connectionSequence,
            update.sequence > connectionSequence
        else { return }
        handle(update.input)
    }

    func handleJoystickSafety(_ update: SequencedConnectionUpdate) {
        if joystickReconnectBoundaryPending, case .connected = update.state { return }
        guard joystickConnectionSequence.map({ update.sequence >= $0 }) ?? true else { return }
        joystickConnectionSequence = update.sequence
        if case .connected = update.state {
            isJoystickConnectionVerified = true
        } else {
            isJoystickConnectionVerified = false
        }
        stopJoystickInput(invalidatePosition: true)
    }

    func completeJoystickReconnectBoundary(_ update: SequencedConnectionUpdate) {
        handleJoystickSafety(update)
        joystickReconnectBoundaryPending = false
    }
}
