import CreatorMicroCore

extension AppModel {
    func startRuntime() {
        guard !isTerminating else { return }
        guard SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess) else {
            reportMissingInputMonitoring()
            return
        }
        guard runtimeTask == nil else { return }
        runtimeTask = Task { [weak self] in
            guard let self else { return }
            await runRuntime()
        }
    }

    private func runRuntime() async {
        let updates = await coordinator.makeDiscreteUpdateStream()
        let radialUpdates = await coordinator.makeRadialUpdateStream()
        let joystickSafetyUpdates = await coordinator.makeJoystickSafetyUpdateStream()
        guard !Task.isCancelled,
            SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess)
        else {
            return
        }
        startJoystickRuntime(
            radialUpdates: radialUpdates,
            safetyUpdates: joystickSafetyUpdates
        )
        defer { cleanUpJoystickRuntime() }
        await coordinator.start()
        guard !Task.isCancelled,
            SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess)
        else {
            await coordinator.stop()
            return
        }
        for await update in updates {
            guard !Task.isCancelled else { break }
            await consume(update)
        }
    }

    private func cleanUpJoystickRuntime() {
        joystickRadialGeneration &+= 1
        joystickRuntimeTask?.cancel()
        joystickRadialRestartTask?.cancel()
        joystickSafetyRuntimeTask?.cancel()
        joystickRuntimeTask = nil
        joystickRadialRestartTask = nil
        joystickSafetyRuntimeTask = nil
    }

    func reconnect() {
        guard !isTerminating else { return }
        refreshSystemAccess()
        guard SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess) else {
            reportMissingInputMonitoring()
            return
        }
        guard runtimeTask != nil else { return }
        beginReconnect()
    }

    func beginReconnect() {
        guard !isTerminating else { return }
        guard SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess) else {
            reportMissingInputMonitoring()
            return
        }
        guard reconnectTask == nil else { return }
        joystickReconnectBoundaryPending = true
        isJoystickConnectionVerified = false
        resetJoystickLocalBoundary()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            defer { reconnectTask = nil }
            await coordinator.stop()
            let stoppedConnection = await coordinator.sequencedConnectionSnapshot()
            completeJoystickReconnectBoundary(stoppedConnection)
            guard !Task.isCancelled, isReady,
                SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess)
            else {
                return
            }
            await coordinator.start()
        }
    }

    func stopRuntimeForPermissionLoss() async {
        let tasks = DeviceRuntimeTasks(model: self)
        isJoystickConnectionVerified = false
        resetJoystickLocalBoundary(restartRadial: false)
        tasks.cancelDeviceTasks()
        runtimeTask = nil
        joystickRuntimeTask = nil
        joystickRadialRestartTask = nil
        joystickSafetyRuntimeTask = nil
        reconnectTask = nil
        pressedControls.removeAll()
        await releaseActiveRoutedActions()
        await coordinator.stop()
        await tasks.waitForDeviceTasks()
        connectionState = .unavailable(
            reason: SystemAccessPolicy.inputMonitoringRequiredMessage
        )
    }

    func shutdown() async {
        prepareForTermination()
        let tasks = RuntimeShutdownTasks(model: self)
        tasks.cancelAll()
        isReady = false
        await flushConfiguration()
        await tasks.waitForStartupTasks()
        clearStartupTaskState()
        await finishShutdown(tasks: tasks)
    }

    private func finishShutdown(tasks: RuntimeShutdownTasks) async {
        let automationStartTask = automationServerStartTask
        automationStartTask?.cancel()
        agentTask?.cancel()
        applicationMonitorTask?.cancel()
        stopAudioMonitoring()
        frontmostApplicationMonitor.stop()
        await releaseActiveRoutedActions()
        await coordinator.stop()
        await tasks.waitForRuntimeTasks()
        stopJoystickInput(invalidatePosition: true)
        if let automationServer { await automationServer.stop() }
        await automationStartTask?.value
        clearRuntimeTaskState()
    }

    private func releaseActiveRoutedActions() async {
        let releases = resetActiveRoutedActions()
        for release in releases {
            await execute(release)
        }
    }

    private func clearStartupTaskState() {
        startupTask = nil
        reconnectTask = nil
        systemAccessReconciliationTask = nil
    }

    private func clearRuntimeTaskState() {
        runtimeTask = nil
        joystickRuntimeTask = nil
        joystickRadialRestartTask = nil
        joystickSafetyRuntimeTask = nil
        agentTask = nil
        automationServerStartTask = nil
        automationServer = nil
        automationSocketPath = nil
        applicationMonitorTask = nil
        configurationSaveTask = nil
    }
}

private struct RuntimeShutdownTasks {
    let startup: Task<Void, Never>?
    let device: DeviceRuntimeTasks
    let systemAccessReconciliation: Task<Void, Never>?

    @MainActor
    init(model: AppModel) {
        startup = model.startupTask
        device = DeviceRuntimeTasks(model: model)
        systemAccessReconciliation = model.systemAccessReconciliationTask
    }

    func cancelAll() {
        startup?.cancel()
        device.cancelDeviceTasks()
        systemAccessReconciliation?.cancel()
    }

    func waitForStartupTasks() async {
        await startup?.value
        await device.reconnect?.value
        await systemAccessReconciliation?.value
    }

    func waitForRuntimeTasks() async {
        await device.waitForRuntimeTasks()
    }
}

private struct DeviceRuntimeTasks {
    let runtime: Task<Void, Never>?
    let joystickRuntime: Task<Void, Never>?
    let joystickRadialRestart: Task<Void, Never>?
    let joystickSafetyRuntime: Task<Void, Never>?
    let reconnect: Task<Void, Never>?

    @MainActor
    init(model: AppModel) {
        runtime = model.runtimeTask
        joystickRuntime = model.joystickRuntimeTask
        joystickRadialRestart = model.joystickRadialRestartTask
        joystickSafetyRuntime = model.joystickSafetyRuntimeTask
        reconnect = model.reconnectTask
    }

    func cancelDeviceTasks() {
        runtime?.cancel()
        joystickRuntime?.cancel()
        joystickRadialRestart?.cancel()
        joystickSafetyRuntime?.cancel()
        reconnect?.cancel()
    }

    func waitForDeviceTasks() async {
        await reconnect?.value
        await waitForRuntimeTasks()
    }

    func waitForRuntimeTasks() async {
        await joystickRuntime?.value
        await joystickRadialRestart?.value
        await joystickSafetyRuntime?.value
        await runtime?.value
    }
}
