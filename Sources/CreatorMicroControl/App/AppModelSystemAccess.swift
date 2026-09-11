extension AppModel {
    func refreshSystemAccess() {
        applySystemAccess(accessController.snapshot())
        launchAtLoginEnabled = loginController.isEnabled
    }

    func requestAccessibility() {
        applySystemAccess(accessController.requestAccessibility())
    }

    func requestInputMonitoring() {
        applySystemAccess(accessController.requestInputMonitoring())
    }

    func openPrivacySettings() {
        guard let pane = SystemAccessPolicy.requiredPrivacyPane(for: systemAccess) else {
            return
        }
        accessController.openPrivacySettings(pane)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard canMutateConfiguration else { return }
        switch loginController.setEnabled(enabled) {
        case .success:
            launchAtLoginEnabled = enabled
            configuration.launchAtLogin = enabled
            saveConfiguration()
        case .failure(let failure):
            lastError = "Launch at login could not be changed: \(failure)"
            launchAtLoginEnabled = loginController.isEnabled
        }
    }

    func applySystemAccess(_ snapshot: SystemAccessSnapshot) {
        let accessChanged = snapshot != systemAccess
        systemAccess = snapshot
        if accessChanged {
            resetJoystickLocalBoundary()
        } else if !snapshot.canControlSystem
            || !SystemAccessPolicy.canStartDeviceRuntime(with: snapshot)
        {
            stopJoystickInput(invalidatePosition: true)
        }
        guard hasStarted, isReady else { return }
        systemAccessGeneration &+= 1
        guard systemAccessReconciliationTask == nil else { return }
        systemAccessReconciliationTask = Task { [weak self] in
            await self?.reconcileSystemAccess()
        }
    }

    func handleSystemEventFailure(_ failure: SystemEventFailure) {
        lastError = failure.userMessage
        applySystemAccess(accessController.snapshot())
    }

    func reportMissingInputMonitoring() {
        connectionState = .unavailable(
            reason: SystemAccessPolicy.inputMonitoringRequiredMessage
        )
    }

    private func reconcileSystemAccess() async {
        while !Task.isCancelled {
            let generation = systemAccessGeneration
            if SystemAccessPolicy.canStartDeviceRuntime(with: systemAccess) {
                startRuntime()
            } else {
                await stopRuntimeForPermissionLoss()
            }
            guard generation != systemAccessGeneration else { break }
        }
        systemAccessReconciliationTask = nil
    }
}
