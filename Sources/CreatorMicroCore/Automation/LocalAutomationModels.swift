import Foundation

public enum LocalAutomationProtocol {
    public static let currentVersion = 1
    public static let maximumLineBytes = 16 * 1_024
    public static let maximumIdentifierBytes = 128
}

enum LocalAutomationLayerWireID {
    static func layer(for value: Int) -> LayerIndex? {
        switch value {
        case 0: .codexCLI
        case 1: .desktop
        case 2: .agentFocus
        case 3: .windowManagement
        case 4: .meetingControls
        case 5: .snippetCommands
        case 6: .claudeCodeCLI
        case 7: .claudeApp
        case 8: .codexApp
        case 9: .cursor
        default: nil
        }
    }

    static func value(for layer: LayerIndex) -> Int {
        switch layer {
        case .codexCLI: 0
        case .desktop: 1
        case .agentFocus: 2
        case .windowManagement: 3
        case .meetingControls: 4
        case .snippetCommands: 5
        case .claudeCodeCLI: 6
        case .claudeApp: 7
        case .codexApp: 8
        case .cursor: 9
        default: layer.rawValue
        }
    }
}

public enum LocalAutomationCommand: Equatable, Sendable {
    case status
    case listLayers
    case setLayer(LayerIndex)
    case triggerBinding(control: ControlID, layer: LayerIndex)
}

public struct LocalAutomationRequest: Equatable, Sendable {
    public let id: String
    public let command: LocalAutomationCommand

    public init(id: String, command: LocalAutomationCommand) {
        self.id = id
        self.command = command
    }
}

public enum LocalAutomationConnection: String, Codable, Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case unavailable
}

public struct LocalAutomationStatus: Codable, Equatable, Sendable {
    public let activeLayer: LayerIndex
    public let isReady: Bool
    public let connection: LocalAutomationConnection
    public let device: DeviceStatus?
    public let layerSource: LayerSelectionSource?

    public init(
        activeLayer: LayerIndex,
        isReady: Bool,
        connection: LocalAutomationConnection,
        device: DeviceStatus? = nil,
        layerSource: LayerSelectionSource? = nil
    ) {
        self.activeLayer = activeLayer
        self.isReady = isReady
        self.connection = connection
        self.device = device
        self.layerSource = layerSource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireID = try container.decode(Int.self, forKey: .activeLayer)
        guard let activeLayer = LocalAutomationLayerWireID.layer(for: wireID) else {
            throw DecodingError.dataCorruptedError(
                forKey: .activeLayer,
                in: container,
                debugDescription: "Unknown automation layer identifier."
            )
        }
        self.init(
            activeLayer: activeLayer,
            isReady: try container.decode(Bool.self, forKey: .isReady),
            connection: try container.decode(LocalAutomationConnection.self, forKey: .connection),
            device: try container.decodeIfPresent(DeviceStatus.self, forKey: .device),
            layerSource: try container.decodeIfPresent(
                LayerSelectionSource.self,
                forKey: .layerSource
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(LocalAutomationLayerWireID.value(for: activeLayer), forKey: .activeLayer)
        try container.encode(isReady, forKey: .isReady)
        try container.encode(connection, forKey: .connection)
        try container.encodeIfPresent(device, forKey: .device)
        try container.encodeIfPresent(layerSource, forKey: .layerSource)
    }

    private enum CodingKeys: String, CodingKey {
        case activeLayer
        case isReady
        case connection
        case device
        case layerSource
    }
}

public struct LocalAutomationLayer: Codable, Equatable, Sendable {
    public let index: LayerIndex
    public let name: String

    public init(index: LayerIndex, name: String) {
        self.index = index
        self.name = name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireID = try container.decode(Int.self, forKey: .index)
        guard let index = LocalAutomationLayerWireID.layer(for: wireID) else {
            throw DecodingError.dataCorruptedError(
                forKey: .index,
                in: container,
                debugDescription: "Unknown automation layer identifier."
            )
        }
        self.init(index: index, name: try container.decode(String.self, forKey: .name))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(LocalAutomationLayerWireID.value(for: index), forKey: .index)
        try container.encode(name, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case index
        case name
    }
}

public enum LocalAutomationActionKind: String, Codable, Equatable, Sendable {
    case none
    case dictation
    case approval
    case returnKey
    case escapeKey
    case deleteKey
    case openTerminal
    case openFinder
    case openApplication
    case switchApplication
    case switchWindow
    case layer
    case shortOrLongPress
    case textSnippet
    case copy
    case paste
    case pastePlainText
    case keyboardShortcut
    case slashCommand
    case actionSequence
    case volume
    case outputMute
    case inputMute
    case pointer
    case appleScript
    case shellCommand
    case agentFocus
    case focusNextAgent
}

public struct LocalAutomationTriggerReceipt: Codable, Equatable, Sendable {
    public let control: ControlID
    public let layer: LayerIndex
    public let action: LocalAutomationActionKind

    public init(
        control: ControlID,
        layer: LayerIndex,
        action: LocalAutomationActionKind
    ) {
        self.control = control
        self.layer = layer
        self.action = action
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wireID = try container.decode(Int.self, forKey: .layer)
        guard let layer = LocalAutomationLayerWireID.layer(for: wireID) else {
            throw DecodingError.dataCorruptedError(
                forKey: .layer,
                in: container,
                debugDescription: "Unknown automation layer identifier."
            )
        }
        self.init(
            control: try container.decode(ControlID.self, forKey: .control),
            layer: layer,
            action: try container.decode(LocalAutomationActionKind.self, forKey: .action)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(control, forKey: .control)
        try container.encode(LocalAutomationLayerWireID.value(for: layer), forKey: .layer)
        try container.encode(action, forKey: .action)
    }

    private enum CodingKeys: String, CodingKey {
        case control
        case layer
        case action
    }
}
