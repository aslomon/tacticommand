import CreatorMicroCore

enum SystemAudioSnapshotUpdatePolicy {
    static func requiresLighting(
        _ previous: SystemAudioSnapshot,
        _ current: SystemAudioSnapshot
    ) -> Bool {
        previous.inputMute != current.inputMute
            || previous.outputMute != current.outputMute
    }
}

extension AppModel {
    func startAudioMonitoring() {
        guard audioMonitorTask == nil else { return }
        if case .failure(let failure) = audioMonitor.start() {
            lastError = "Audio monitoring failed: \(failure)"
            refreshAudioState()
            return
        }
        let snapshots = audioMonitor.snapshots
        audioMonitorTask = Task { [weak self] in
            for await snapshot in snapshots {
                guard !Task.isCancelled else { break }
                self?.applyAudioSnapshot(snapshot)
            }
        }
    }

    func stopAudioMonitoring() {
        audioMonitorTask?.cancel()
        audioMonitorTask = nil
        audioMonitor.stop()
    }

    func refreshAudioState() {
        applyAudioSnapshot(actionExecutor.currentAudioSnapshot())
    }

    func applyAudioSnapshot(_ snapshot: SystemAudioSnapshot) {
        guard audioSnapshot != snapshot else { return }
        let previous = audioSnapshot
        audioSnapshot = snapshot
        guard SystemAudioSnapshotUpdatePolicy.requiresLighting(previous, snapshot) else {
            return
        }
        Task { await synchronizeLighting() }
    }
}
