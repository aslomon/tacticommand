import Foundation

public enum LocalAutomationProtocol {
    public static let currentVersion = 1
    public static let maximumLineBytes = 16 * 1_024
    public static let maximumIdentifierBytes = 128
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
}

public struct LocalAutomationLayer: Codable, Equatable, Sendable {
    public let index: LayerIndex
    public let name: String

    public init(index: LayerIndex, name: String) {
        self.index = index
        self.name = name
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
}

public enum LocalAutomationResult: Codable, Equatable, Sendable {
    case status(LocalAutomationStatus)
    case layers([LocalAutomationLayer])
    case layerSelected(LayerIndex)
    case bindingTriggered(LocalAutomationTriggerReceipt)

    private enum CodingKeys: String, CodingKey {
        case kind
        case status
        case layers
        case activeLayer
        case binding
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .status(let status):
            try container.encode("status", forKey: .kind)
            try container.encode(status, forKey: .status)
        case .layers(let layers):
            try container.encode("layers", forKey: .kind)
            try container.encode(layers, forKey: .layers)
        case .layerSelected(let layer):
            try container.encode("layerSelected", forKey: .kind)
            try container.encode(layer, forKey: .activeLayer)
        case .bindingTriggered(let binding):
            try container.encode("bindingTriggered", forKey: .kind)
            try container.encode(binding, forKey: .binding)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "status":
            self = .status(try container.decode(LocalAutomationStatus.self, forKey: .status))
        case "layers":
            self = .layers(try container.decode([LocalAutomationLayer].self, forKey: .layers))
        case "layerSelected":
            self = .layerSelected(try container.decode(LayerIndex.self, forKey: .activeLayer))
        case "bindingTriggered":
            self = .bindingTriggered(
                try container.decode(LocalAutomationTriggerReceipt.self, forKey: .binding)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown local automation result kind."
            )
        }
    }
}

public enum LocalAutomationErrorCode: String, Codable, Equatable, Sendable {
    case invalidRequest = "invalid_request"
    case invalidParameters = "invalid_parameters"
    case unsupportedVersion = "unsupported_version"
    case methodNotFound = "method_not_found"
    case frameTooLarge = "frame_too_large"
    case forbiddenAction = "forbidden_action"
    case bindingNotFound = "binding_not_found"
    case executionFailed = "execution_failed"
    case internalError = "internal_error"
}

public struct LocalAutomationError: Codable, Error, Equatable, Sendable {
    public let code: LocalAutomationErrorCode
    public let message: String
    public let actionKind: LocalAutomationActionKind?

    public init(
        code: LocalAutomationErrorCode,
        message: String,
        actionKind: LocalAutomationActionKind? = nil
    ) {
        self.code = code
        self.message = message
        self.actionKind = actionKind
    }
}

public struct LocalAutomationProtocolFailure: Error, Equatable, Sendable {
    public let requestID: String?
    public let error: LocalAutomationError

    public init(requestID: String?, error: LocalAutomationError) {
        self.requestID = requestID
        self.error = error
    }
}

public struct LocalAutomationResponse: Codable, Equatable, Sendable {
    public let version: Int
    public let id: String?
    public let result: LocalAutomationResult?
    public let error: LocalAutomationError?

    public static func success(
        id: String,
        result: LocalAutomationResult
    ) -> Self {
        Self(version: LocalAutomationProtocol.currentVersion, id: id, result: result, error: nil)
    }

    public static func failure(id: String?, error: LocalAutomationError) -> Self {
        Self(version: LocalAutomationProtocol.currentVersion, id: id, result: nil, error: error)
    }
}
