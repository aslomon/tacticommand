import Foundation

public enum MicroDeviceModel: Equatable, Sendable {
    case creator13
    case codex6
    case unknown
}

public enum TopRowOrdering: Equatable, Sendable {
    case leftToRight
    case rightToLeft
}

/// Real, PID-derived hardware capability. Conservative by design: an unknown product
/// identifier is treated as a 6-key device so no UI or lighting ever assumes a Creator13
/// scene it cannot verify is physically present.
public struct DeviceCapabilityProfile: Equatable, Sendable {
    public let model: MicroDeviceModel
    public let independentlyLitKeyCount: Int
    public let supportsIndependentActionKeyLighting: Bool
    public let wideKeyPair: [ControlID]?
    public let topRowOrdering: TopRowOrdering

    public init(productIdentifier: Int?) {
        let resolvedModel = productIdentifier.map(MicroDeviceModel.init(productIdentifier:)) ?? .unknown
        model = resolvedModel
        switch resolvedModel {
        case .creator13:
            independentlyLitKeyCount = 13
            supportsIndependentActionKeyLighting = true
            wideKeyPair = [.action10, .action11]
            // Physical Creator Micro 2 input verification: the left top key sends AG00.
            // Keep input geometry separate from assumptions about LED wiring.
            topRowOrdering = .leftToRight
        case .codex6, .unknown:
            independentlyLitKeyCount = MicroProtocolConstants.agentKeyCount
            supportsIndependentActionKeyLighting = false
            wideKeyPair = nil
            topRowOrdering = .leftToRight
        }
    }

    /// Every ControlID the firmware can independently color on this model, in ascending
    /// AG-slot order (agent0...agent5, then action6...action12 for Creator13 only).
    public var independentlyLitControls: [ControlID] {
        let agentControls = ControlID.allCases
            .filter { $0.agentIndex != nil }
            .sorted { $0.agentIndex! < $1.agentIndex! }
        guard supportsIndependentActionKeyLighting else { return agentControls }
        let actionControls: [ControlID] = [
            .action6, .action7, .action8, .action9, .action10, .action11, .action12,
        ]
        return agentControls + actionControls
    }
}

extension MicroDeviceModel {
    fileprivate init(productIdentifier: Int) {
        if MicroProtocolConstants.creatorMicroProductIdentifiers.contains(productIdentifier) {
            self = .creator13
        } else if productIdentifier == MicroProtocolConstants.productIdentifier {
            self = .codex6
        } else {
            self = .unknown
        }
    }
}
