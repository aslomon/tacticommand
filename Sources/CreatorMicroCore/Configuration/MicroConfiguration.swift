import Foundation

public struct LayerConfiguration: Codable, Equatable, Identifiable, Sendable {
    public let id: LayerIndex
    public var name: String
    public var bindings: [ControlID: CreatorAction]
    public var joystick: LayerJoystickConfiguration?

    public init(
        id: LayerIndex,
        name: String,
        bindings: [ControlID: CreatorAction] = [:],
        joystick: LayerJoystickConfiguration? = nil
    ) {
        self.id = id
        self.name = name
        self.bindings = bindings
        self.joystick = joystick
    }

    public func action(for control: ControlID) -> CreatorAction {
        bindings[control] ?? .none
    }

    public mutating func assign(_ action: CreatorAction, to control: ControlID) {
        if action == .none {
            bindings.removeValue(forKey: control)
        } else {
            bindings[control] = action
        }
    }
}

public struct ApplicationLayerRule: Codable, Equatable, Identifiable, Sendable {
    public let bundleIdentifier: String
    public var layer: LayerIndex

    public var id: String { bundleIdentifier }

    public init(bundleIdentifier: String, layer: LayerIndex) {
        self.bundleIdentifier = bundleIdentifier
        self.layer = layer
    }
}

public struct JoystickConfiguration: Codable, Equatable, Sendable {
    public var deadZone: Double
    public var maximumSpeed: Double

    public init(deadZone: Double = 0.12, maximumSpeed: Double = 1_100) {
        self.deadZone = min(max(deadZone, 0), 0.95)
        self.maximumSpeed = min(max(maximumSpeed, 100), 4_000)
    }
}

public enum JoystickMode: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case arrowKeys
    case pointer
    case off
}

public struct LayerJoystickConfiguration: Codable, Equatable, Sendable {
    public var mode: JoystickMode
    public var deadZone: Double
    public var maximumSpeed: Double

    public init(
        mode: JoystickMode = .pointer,
        deadZone: Double = 0.12,
        maximumSpeed: Double = 1_100
    ) {
        self.mode = mode
        self.deadZone = min(max(deadZone, 0), 0.95)
        self.maximumSpeed = min(max(maximumSpeed, 100), 4_000)
    }

    public init(
        inheriting configuration: JoystickConfiguration,
        mode: JoystickMode = .pointer
    ) {
        self.init(
            mode: mode,
            deadZone: configuration.deadZone,
            maximumSpeed: configuration.maximumSpeed
        )
    }

    public var pointerConfiguration: JoystickConfiguration? {
        guard mode == .pointer else { return nil }
        return JoystickConfiguration(
            deadZone: deadZone,
            maximumSpeed: maximumSpeed
        )
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case isEnabled
        case deadZone
        case maximumSpeed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedMode = try container.decodeIfPresent(JoystickMode.self, forKey: .mode) {
            mode = decodedMode
        } else {
            let enabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
            mode = enabled ? .pointer : .off
        }
        deadZone = try container.decode(Double.self, forKey: .deadZone)
        maximumSpeed = try container.decode(Double.self, forKey: .maximumSpeed)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(deadZone, forKey: .deadZone)
        try container.encode(maximumSpeed, forKey: .maximumSpeed)
    }
}

public struct MicroConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 8

    public var schemaVersion: Int
    public var microphoneLayout: MicrophoneLayout
    public var layers: [LayerConfiguration]
    public var applicationLayerRules: [ApplicationLayerRule]
    public var joystick: JoystickConfiguration
    public var launchAtLogin: Bool

    public init(
        schemaVersion: Int = currentSchemaVersion,
        microphoneLayout: MicrophoneLayout,
        layers: [LayerConfiguration],
        applicationLayerRules: [ApplicationLayerRule] = [],
        joystick: JoystickConfiguration = JoystickConfiguration(),
        launchAtLogin: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.microphoneLayout = microphoneLayout
        self.layers = layers
        self.applicationLayerRules = applicationLayerRules
        self.joystick = joystick
        self.launchAtLogin = launchAtLogin
    }

    public func layer(_ id: LayerIndex) -> LayerConfiguration? {
        layers.first { $0.id == id }
    }

    public mutating func assign(
        action: CreatorAction,
        to control: ControlID,
        on layerID: LayerIndex
    ) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].assign(action, to: control)
    }

    public mutating func setJoystick(
        _ joystick: LayerJoystickConfiguration?,
        on layerID: LayerIndex
    ) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].joystick = joystick
    }

    public mutating func applyPreset(
        _ presetID: MicroLayerPresetID,
        to layerID: LayerIndex
    ) {
        guard let desktopChassis = layer(.desktop),
            let index = layers.firstIndex(where: { $0.id == layerID })
        else {
            return
        }
        layers[index] = MicroLayerPresetCatalog.preset(for: presetID).layer(
            for: layerID,
            desktopChassis: desktopChassis
        )
    }

    public func resolvedJoystick(
        for layerID: LayerIndex
    ) -> LayerJoystickConfiguration? {
        guard let layer = layer(layerID) else { return nil }
        return layer.joystick ?? LayerJoystickConfiguration(inheriting: joystick)
    }
}
