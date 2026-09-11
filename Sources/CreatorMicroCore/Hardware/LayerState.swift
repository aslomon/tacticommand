import Foundation

public struct LayerIndex: RawRepresentable, Codable, Hashable, Sendable {
    public static let codex = LayerIndex(uncheckedRawValue: 0)
    public static let desktop = LayerIndex(uncheckedRawValue: 1)
    public static let agents = LayerIndex(uncheckedRawValue: 2)
    public static let windows = LayerIndex(uncheckedRawValue: 3)
    public static let meetings = LayerIndex(uncheckedRawValue: 4)
    public static let snippets = LayerIndex(uncheckedRawValue: 5)
    public static let all: [LayerIndex] = [
        .codex, .desktop, .agents, .windows, .meetings, .snippets,
    ]

    public let rawValue: Int

    public init?(rawValue: Int) {
        guard (0..<MicroProtocolConstants.layerCount).contains(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let value = LayerIndex(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Layer index must be between 0 and 5."
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private init(uncheckedRawValue: Int) {
        rawValue = uncheckedRawValue
    }
}

public enum LayerCommand: Codable, Hashable, Sendable {
    case next
    case previous
    case select(LayerIndex)

    public func destination(from current: LayerIndex) -> LayerIndex {
        switch self {
        case .next:
            return LayerIndex.all[(current.rawValue + 1) % LayerIndex.all.count]
        case .previous:
            let index = (current.rawValue - 1 + LayerIndex.all.count) % LayerIndex.all.count
            return LayerIndex.all[index]
        case .select(let layer):
            return layer
        }
    }
}

public enum LayerSelectionSource: String, Codable, Hashable, Sendable {
    case launchDefault
    case editor
    case physicalKey
    case applicationRule
    case automation
}

public struct LayerSelectionState: Codable, Hashable, Sendable {
    public private(set) var active: LayerIndex
    public private(set) var source: LayerSelectionSource
    public private(set) var firmwareLayerIndex: Int?

    public init(
        active: LayerIndex = .desktop,
        source: LayerSelectionSource = .launchDefault
    ) {
        self.active = active
        self.source = source
        firmwareLayerIndex = nil
    }

    @discardableResult
    public mutating func select(
        _ layer: LayerIndex,
        source: LayerSelectionSource
    ) -> Bool {
        let changed = active != layer || self.source != source
        active = layer
        self.source = source
        return changed
    }

    @discardableResult
    public mutating func observe(status: DeviceStatus) -> Bool {
        let changed = firmwareLayerIndex != status.layerIndex
        firmwareLayerIndex = status.layerIndex
        return changed
    }
}
