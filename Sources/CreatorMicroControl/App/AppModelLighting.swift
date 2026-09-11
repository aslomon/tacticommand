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
            try await coordinator.send(payload: ambientLightingPayload())
            try await coordinator.send(payload: agentLightingPayload())
        } catch let error as MicroConnectionError where error == .notConnected {
            return
        } catch {
            lastError = "Device lighting update failed: \(error.localizedDescription)"
        }
    }

    private func agentLightingPayload() throws -> Data {
        let lights = try agentSnapshot.slots.map { slot in
            if let lighting = try semanticLighting(for: slot.id.rawValue) {
                return lighting
            }
            return try AgentKeyLighting(
                index: slot.id.rawValue,
                color: color(for: slot.status),
                brightness: slot.status == .unavailable ? 0 : 1,
                effect: effect(for: slot.status),
                speed: animationSpeed(for: slot.status)
            )
        }
        return try LightingPayloadBuilder.agentStatus(lights)
    }

    private func semanticLighting(for index: Int) throws -> AgentKeyLighting? {
        guard let control = ControlID.allCases.first(where: { $0.agentIndex == index }) else {
            return nil
        }
        let action = selectedLayer.action(for: control)
        guard
            let state = KeyActionLiveState.resolve(
                action: action,
                audio: audioSnapshot,
                isDictating: isDictating
            )
        else {
            return nil
        }
        return try state.agentKeyLighting(index: index)
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

    private func color(for status: AgentStatus) -> RGBColor {
        switch status {
        case .idle: .white
        case .working: RGBColor(red: 48, green: 79, blue: 254)
        case .waiting: RGBColor(red: 255, green: 109, blue: 0)
        case .complete: RGBColor(red: 0, green: 255, blue: 76)
        case .error: RGBColor(red: 255, green: 0, blue: 51)
        case .unavailable: .black
        }
    }

    private func effect(for status: AgentStatus) -> LightingEffect {
        switch status {
        case .working: .shallowBreath
        case .waiting, .error: .breath
        case .idle, .complete: .solid
        case .unavailable: .off
        }
    }

    private func animationSpeed(for status: AgentStatus) -> Double {
        switch status {
        case .working: 0.3
        case .waiting: 0.55
        case .error: 0.8
        case .idle, .complete, .unavailable: 0
        }
    }
}
