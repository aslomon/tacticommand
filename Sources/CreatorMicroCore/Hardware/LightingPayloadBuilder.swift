import Foundation

public struct RGBColor: RawRepresentable, Codable, Hashable, Sendable {
    public static let black = RGBColor(red: 0, green: 0, blue: 0)
    public static let red = RGBColor(red: 255, green: 0, blue: 0)
    public static let green = RGBColor(red: 0, green: 255, blue: 0)
    public static let blue = RGBColor(red: 0, green: 0, blue: 255)
    public static let white = RGBColor(red: 255, green: 255, blue: 255)

    public let rawValue: Int

    public init?(rawValue: Int) {
        guard (0...0xFFFFFF).contains(rawValue) else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        rawValue = Int(red) << 16 | Int(green) << 8 | Int(blue)
    }
}

public enum LightingEffect: Int, Codable, CaseIterable, Hashable, Sendable {
    case off = 0
    case solid = 1
    case snake = 2
    case rainbow = 3
    case breath = 4
    case gradient = 5
    case shallowBreath = 6
}

public enum LightingPayloadError: Error, Equatable, LocalizedError {
    case invalidAgentIndex(Int)
    case invalidUnit(field: String, value: Double)
    case requiresAllAgentKeys
    case duplicateAgentKey(Int)
    case emptyRGBConfiguration
    case emptyKeyStatus

    public var errorDescription: String? {
        switch self {
        case .invalidAgentIndex(let index):
            "Agent key index must be between 0 and 5, got \(index)."
        case .invalidUnit(let field, let value):
            "Lighting \(field) must be between 0 and 1, got \(value)."
        case .requiresAllAgentKeys:
            "An agent status payload must contain all six Agent keys."
        case .duplicateAgentKey(let index):
            "Agent status contains duplicate key index \(index)."
        case .emptyRGBConfiguration:
            "RGB configuration requires ambient or key lighting."
        case .emptyKeyStatus:
            "A key lighting update requires at least one key."
        }
    }
}

public struct AgentKeyLighting: Codable, Hashable, Sendable {
    public let index: Int
    public let color: RGBColor
    public let brightness: Double
    public let effect: LightingEffect
    public let speed: Double
    public let syncKeys: Bool?
    public let syncAmbient: Bool?

    public init(
        index: Int,
        color: RGBColor,
        brightness: Double = 1,
        effect: LightingEffect = .solid,
        speed: Double = 0,
        syncKeys: Bool? = nil,
        syncAmbient: Bool? = nil,
        validIndices: Range<Int> = 0..<MicroProtocolConstants.agentKeyCount
    ) throws {
        guard validIndices.contains(index) else {
            throw LightingPayloadError.invalidAgentIndex(index)
        }
        try validateUnit(brightness, field: "brightness")
        try validateUnit(speed, field: "speed")
        self.index = index
        self.color = color
        self.brightness = brightness
        self.effect = effect
        self.speed = speed
        self.syncKeys = syncKeys
        self.syncAmbient = syncAmbient
    }
}

public struct ZoneLighting: Codable, Hashable, Sendable {
    public let color: RGBColor
    public let brightness: Double
    public let effect: LightingEffect
    public let speed: Double

    public init(
        color: RGBColor,
        brightness: Double = 1,
        effect: LightingEffect = .solid,
        speed: Double = 0
    ) throws {
        try validateUnit(brightness, field: "brightness")
        try validateUnit(speed, field: "speed")
        self.color = color
        self.brightness = brightness
        self.effect = effect
        self.speed = speed
    }
}

public enum LightingPayloadBuilder {
    public static func agentStatus(_ lights: [AgentKeyLighting]) throws -> Data {
        guard lights.count == MicroProtocolConstants.agentKeyCount else {
            throw LightingPayloadError.requiresAllAgentKeys
        }
        let identifiers = Set(lights.map(\.index))
        guard identifiers.count == lights.count else {
            let duplicate = duplicateIndex(in: lights) ?? -1
            throw LightingPayloadError.duplicateAgentKey(duplicate)
        }
        guard identifiers == Set(0..<MicroProtocolConstants.agentKeyCount) else {
            throw LightingPayloadError.requiresAllAgentKeys
        }
        let entries = lights.sorted { $0.index < $1.index }.map(AgentStatusEntry.init)
        return try encode(Notification(method: "v.oai.thstatus", parameters: entries))
    }

    /// Same wire method as `agentStatus`, but bounded by the real connected device's
    /// capability instead of the fixed 6-key agent protocol. Creator13 can address all 13
    /// AG00...AG12 positions this way; Codex6/unknown stay at 6 and reuse `agentStatus`'s
    /// validation shape.
    public static func keyStatus(
        _ lights: [AgentKeyLighting],
        capability: DeviceCapabilityProfile
    ) throws -> Data {
        let expectedCount = capability.independentlyLitKeyCount
        guard lights.count == expectedCount else {
            throw LightingPayloadError.requiresAllAgentKeys
        }
        let identifiers = Set(lights.map(\.index))
        guard identifiers.count == lights.count else {
            let duplicate = duplicateIndex(in: lights) ?? -1
            throw LightingPayloadError.duplicateAgentKey(duplicate)
        }
        guard identifiers == Set(0..<expectedCount) else {
            throw LightingPayloadError.requiresAllAgentKeys
        }
        let entries = lights.sorted { $0.index < $1.index }.map(AgentStatusEntry.init)
        return try encode(Notification(method: "v.oai.thstatus", parameters: entries))
    }

    /// Creator firmware accepts updates for individual threads. Codex/unknown retain
    /// their established all-six-key contract until partial updates are verified there.
    public static func keyStatusUpdates(
        _ lights: [AgentKeyLighting],
        capability: DeviceCapabilityProfile
    ) throws -> Data {
        guard capability.supportsIndependentActionKeyLighting else {
            return try agentStatus(lights)
        }
        guard !lights.isEmpty else { throw LightingPayloadError.emptyKeyStatus }
        if let duplicate = duplicateIndex(in: lights) {
            throw LightingPayloadError.duplicateAgentKey(duplicate)
        }
        for light in lights where !(0..<capability.independentlyLitKeyCount).contains(light.index) {
            throw LightingPayloadError.invalidAgentIndex(light.index)
        }
        let entries = lights.sorted { $0.index < $1.index }.map(AgentStatusEntry.init)
        return try encode(Notification(method: "v.oai.thstatus", parameters: entries))
    }

    public static func uniformAgentStatus(
        color: RGBColor,
        brightness: Double = 1,
        effect: LightingEffect = .solid,
        speed: Double = 0
    ) throws -> Data {
        let lights = try (0..<MicroProtocolConstants.agentKeyCount).map { index in
            try AgentKeyLighting(
                index: index,
                color: color,
                brightness: brightness,
                effect: effect,
                speed: speed
            )
        }
        return try agentStatus(lights)
    }

    public static func rgbConfiguration(
        ambient: ZoneLighting?,
        keys: ZoneLighting?
    ) throws -> Data {
        guard ambient != nil || keys != nil else {
            throw LightingPayloadError.emptyRGBConfiguration
        }
        let parameters = RGBConfigurationParameters(
            ambient: ambient.map(ZoneEntry.init),
            keys: keys.map(ZoneEntry.init)
        )
        return try encode(Notification(method: "v.oai.rgbcfg", parameters: parameters))
    }

    private static func duplicateIndex(in lights: [AgentKeyLighting]) -> Int? {
        var seen: Set<Int> = []
        for light in lights where !seen.insert(light.index).inserted {
            return light.index
        }
        return nil
    }

    private static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}

private func validateUnit(_ value: Double, field: String) throws {
    guard value.isFinite, (0...1).contains(value) else {
        throw LightingPayloadError.invalidUnit(field: field, value: value)
    }
}

private struct Notification<Parameters: Encodable>: Encodable {
    let method: String
    let parameters: Parameters

    enum CodingKeys: String, CodingKey {
        case method
        case parameters = "params"
    }
}

private struct AgentStatusEntry: Encodable {
    let identifier: Int
    let color: Int
    let brightness: Double
    let effect: Int
    let speed: Double
    let syncKeys: Int?
    let syncAmbient: Int?

    init(_ lighting: AgentKeyLighting) {
        identifier = lighting.index
        color = lighting.color.rawValue
        brightness = lighting.brightness
        effect = lighting.effect.rawValue
        speed = lighting.speed
        syncKeys = lighting.syncKeys.map { $0 ? 1 : 0 }
        syncAmbient = lighting.syncAmbient.map { $0 ? 1 : 0 }
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case color = "c"
        case brightness = "b"
        case effect = "e"
        case speed = "s"
        case syncKeys = "sk"
        case syncAmbient = "sa"
    }
}

private struct ZoneEntry: Encodable {
    let effect: Int
    let brightness: Double
    let speed: Double
    let color: Int

    init(_ lighting: ZoneLighting) {
        effect = lighting.effect.rawValue
        brightness = lighting.brightness
        speed = lighting.speed
        color = lighting.color.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case effect = "e"
        case brightness = "b"
        case speed = "s"
        case color = "c"
    }
}

private struct RGBConfigurationParameters: Encodable {
    let ambient: ZoneEntry?
    let keys: ZoneEntry?
}
