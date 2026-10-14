import CreatorMicroCore
import Foundation

/// Immutable desired state. Deltas are calculated against the last fully sent state,
/// never against queued frames that may be replaced before reaching the device.
struct DeviceLightingFrame: Equatable, Sendable {
    let ambient: Data
    let sharedKeys: Data
    let keys: [AgentKeyLighting]
    let capability: DeviceCapabilityProfile

    func payloads(comparedTo previous: Self?) throws -> [Data] {
        guard let previous, previous.capability == capability else {
            return [ambient, sharedKeys, try LightingPayloadBuilder.keyStatus(keys, capability: capability)]
        }
        var payloads: [Data] = []
        if keys != previous.keys {
            if capability.supportsIndependentActionKeyLighting {
                let changed = keys.filter { key in
                    previous.keys.first { $0.index == key.index } != key
                }
                if !changed.isEmpty {
                    payloads.append(try LightingPayloadBuilder.keyStatusUpdates(changed, capability: capability))
                }
            } else {
                payloads.append(try LightingPayloadBuilder.agentStatus(keys))
            }
        }
        // Prioritize the key's visible acknowledgement over secondary ambient effects.
        if ambient != previous.ambient { payloads.append(ambient) }
        if sharedKeys != previous.sharedKeys { payloads.append(sharedKeys) }
        return payloads
    }
}
