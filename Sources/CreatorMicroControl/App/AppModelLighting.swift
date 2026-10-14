import CreatorMicroCore
import Foundation

extension AppModel {
    func refreshLightingAfterLayerChange() {
        Task { [weak self] in
            await self?.synchronizeLighting()
        }
    }

    func synchronizeLighting() async {
        guard case .connected = connectionState else { return }
        do {
            desiredLighting = try DeviceLightingFrame(
                ambient: ambientLightingPayload(), sharedKeys: sharedKeyLightingPayload(),
                keys: keyLights(), capability: capabilityProfile)
            startLightingPublisher()
        } catch {
            lastError = "Device lighting update failed: \(error.localizedDescription)"
        }
    }

    private func startLightingPublisher() {
        guard lightingTask == nil else { return }
        let generation = lightingGeneration
        lightingTask = Task { [weak self] in
            guard let self else { return }
            defer {
                lightingTask = nil
                if desiredLighting != nil { startLightingPublisher() }
            }
            do {
                while generation == lightingGeneration, desiredLighting != nil {
                    if let lastLightingInstant {
                        let deadline = lastLightingInstant.advanced(by: .milliseconds(70))
                        if deadline > ContinuousClock().now { try await Task.sleep(until: deadline) }
                    }
                    try Task.checkCancellation()
                    guard generation == lightingGeneration, let frame = desiredLighting else { return }
                    desiredLighting = nil
                    guard frame != lastLighting else { continue }
                    lastLightingInstant = ContinuousClock().now
                    for payload in try frame.payloads(comparedTo: lastLighting) {
                        try Task.checkCancellation()
                        try await coordinator.send(payload: payload)
                    }
                    guard generation == lightingGeneration else { return }
                    lastLighting = frame
                }
            } catch {
                guard generation == lightingGeneration, !(error is CancellationError) else { return }
                if error as? MicroConnectionError != .notConnected {
                    lastError = "Device lighting update failed: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Exact UI contract: the same resolved appearance the hardware will show for `control`,
    /// or nil when it is unassigned and has no signal (render as dim/off). Priority order:
    /// observed audio/dictation signal > agent status (Agent Focus layer only) > the bound
    /// action's resting function-category color.
    func keyAppearance(for control: ControlID) -> LightingKeyAppearance? {
        _ = lightingFeedbackRevision
        let control = canonicalControl(control)
        let feedback = lightingFeedback.feedback(for: control, at: ContinuousClock().now)
        let action = selectedLayer.action(for: control)
        let observedSignal = KeyActionLiveState.resolve(
            action: action,
            audio: audioSnapshot,
            isDictating: isDictating
        )?.appearance
        let agentStatusAppearance =
            layerSelection.active == .agentFocus
            ? control.agentIndex.flatMap(agentStatusAppearance(agentIndex:))
            : nil
        let appearance = LightingPriorityResolver.resolve(
            failure: feedback.isFailing
                ? LightingKeyAppearance(
                    color: SemanticLightingPalette.audioMuted, brightness: 1, effect: .breath, speed: 0.8)
                : nil,
            observedSignal: observedSignal,
            agentStatus: agentStatusAppearance,
            category: FunctionCategory.classify(action),
            isPressed: !lightingFeedback.tracks(control) && pressedControls.contains(control)
        )
        guard let appearance, !feedback.isFailing else { return appearance }
        return LightingKeyAppearance(
            color: appearance.color,
            brightness: appearance.brightness + (1 - appearance.brightness) * feedback.pressLift,
            effect: appearance.effect, speed: appearance.speed)
    }

    private func keyLights() throws -> [AgentKeyLighting] {
        let capability = capabilityProfile
        return try capability.independentlyLitControls.enumerated()
            .map { slot, control in try wireLighting(slot: slot, control: control) }
    }

    private func wireLighting(slot: Int, control: ControlID?) throws -> AgentKeyLighting {
        let appearance = control.flatMap(keyAppearance(for:))
        return try AgentKeyLighting(
            index: slot,
            color: appearance?.color ?? .black,
            brightness: appearance?.brightness ?? 0,
            effect: appearance?.effect ?? .off,
            speed: appearance?.speed ?? 0,
            validIndices: 0..<capabilityProfile.independentlyLitKeyCount
        )
    }

    /// Reuses `AgentStatus.deviceLight`'s approved semantic tokens, but `.unavailable` (no
    /// agent assigned) returns nil instead of forcing black, so a key that also carries a
    /// real binding keeps showing its function-category color instead of going dark.
    private func agentStatusAppearance(agentIndex: Int) -> LightingKeyAppearance? {
        guard let slot = agentSnapshot.slots.first(where: { $0.id.rawValue == agentIndex }),
            slot.status != .unavailable
        else {
            return nil
        }
        return LightingKeyAppearance(
            color: agentStatusColor(slot.status),
            brightness: 1,
            effect: agentStatusEffect(slot.status),
            speed: agentStatusSpeed(slot.status)
        )
    }

    private func agentStatusColor(_ status: AgentStatus) -> RGBColor {
        switch status {
        case .idle: .white
        case .working: RGBColor(red: 48, green: 79, blue: 254)
        case .waiting: RGBColor(red: 255, green: 109, blue: 0)
        case .complete: RGBColor(red: 0, green: 255, blue: 76)
        case .error: RGBColor(red: 255, green: 0, blue: 51)
        case .unavailable: .black
        }
    }

    private func agentStatusEffect(_ status: AgentStatus) -> LightingEffect {
        switch status {
        case .working: .shallowBreath
        case .waiting, .error: .breath
        case .idle, .complete: .solid
        case .unavailable: .off
        }
    }

    private func agentStatusSpeed(_ status: AgentStatus) -> Double {
        switch status {
        case .working: 0.3
        case .waiting: 0.55
        case .error: 0.8
        case .idle, .complete, .unavailable: 0
        }
    }

    private func ambientLightingPayload() throws -> Data {
        let zone = try ZoneLighting(
            color: ambientColor,
            brightness: ambientBrightness,
            effect: ambientEffect,
            speed: ambientSpeed
        )
        return try LightingPayloadBuilder.rgbConfiguration(ambient: zone, keys: nil)
    }

    private func sharedKeyLightingPayload() throws -> Data {
        let shared = try ZoneLighting(
            color: SemanticLightingPalette.textClipboard,
            brightness: SemanticLightingPalette.idleBrightness)
        return try LightingPayloadBuilder.rgbConfiguration(ambient: nil, keys: shared)
    }

    private var ambientColor: RGBColor {
        switch audioSnapshot.inputMute {
        case .muted: .red
        case .unmuted where isDictating: RGBColor(red: 36, green: 200, blue: 219)
        case .unmuted: .green
        case .mixed: RGBColor(red: 255, green: 109, blue: 0)
        case .unavailable: RGBColor(red: 255, green: 180, blue: 0)
        }
    }

    private var ambientBrightness: Double {
        switch audioSnapshot.inputMute {
        case .muted, .mixed: 0.65
        case .unmuted: 0.28
        case .unavailable: 0.35
        }
    }

    private var ambientEffect: LightingEffect {
        switch audioSnapshot.inputMute {
        case .muted, .mixed: .breath
        case .unmuted: .solid
        case .unavailable: .shallowBreath
        }
    }

    private var ambientSpeed: Double {
        switch audioSnapshot.inputMute {
        case .muted, .mixed: 0.45
        case .unmuted: 0
        case .unavailable: 0.25
        }
    }
}
