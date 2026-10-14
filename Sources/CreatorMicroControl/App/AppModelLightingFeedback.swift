import CreatorMicroCore
import Foundation

extension AppModel {
    func canonicalControl(_ control: ControlID) -> ControlID {
        capabilityProfile.wideKeyPair?.contains(control) == true ? .action10 : control
    }

    func configureRuntimeRouter() {
        runtimeRouter = MicroRuntimeRouter(
            microphoneLayout: capabilityProfile.wideKeyPair != nil
                ? .linked : configuration.microphoneLayout)
    }

    func recordLightingInput(_ input: MicroInputEvent, routed: [RoutedCreatorAction]) {
        let control = canonicalControl(input.control)
        let now = ContinuousClock().now
        let isWide = capabilityProfile.wideKeyPair?.contains(input.control) == true
        if isWide && routed.isEmpty { return }
        switch input.phase {
        case .pressed: lightingFeedback.press(control, at: now)
        case .released: lightingFeedback.release(control, at: now)
        case .pulse:
            lightingFeedback.press(control, at: now.advanced(by: .milliseconds(-90)))
            lightingFeedback.release(control, at: now)
        }
        scheduleLightingFeedback()
    }

    func recordLightingFailure(control: ControlID, generation: UInt64) {
        guard generation == lightingGeneration else { return }
        lightingFeedback.failure(canonicalControl(control), at: ContinuousClock().now)
        scheduleLightingFeedback()
    }

    func resetLightingBoundary() {
        lightingGeneration &+= 1
        lightingTask?.cancel()
        feedbackTask?.cancel()
        // Keep the publisher slot occupied until its atomic in-flight payload finishes.
        feedbackTask = nil
        desiredLighting = nil
        lastLighting = nil
        lightingFeedback.reset()
        lightingFeedbackRevision &+= 1
        pressedControls.removeAll()
    }

    func scheduleLightingFeedback() {
        lightingFeedbackRevision &+= 1
        Task { await synchronizeLighting() }
        guard feedbackTask == nil else { return }
        let generation = lightingGeneration
        feedbackTask = Task { [weak self] in
            guard let self else { return }
            while generation == lightingGeneration,
                let deadline = lightingFeedback.nextDeadline(at: ContinuousClock().now)
            {
                let delay = min(ContinuousClock().now.duration(to: deadline), .milliseconds(70))
                do { try await Task.sleep(for: max(delay, .milliseconds(1))) } catch { return }
                guard generation == lightingGeneration else { return }
                lightingFeedback.prune(at: ContinuousClock().now)
                lightingFeedbackRevision &+= 1
                await synchronizeLighting()
            }
            if generation == lightingGeneration { feedbackTask = nil }
        }
    }
}
