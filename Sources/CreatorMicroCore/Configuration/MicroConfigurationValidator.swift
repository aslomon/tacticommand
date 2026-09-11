import Foundation

public struct MicroConfigurationValidationFailure: Error, Equatable, Sendable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum MicroConfigurationValidator {
    public static let maximumFileBytes = 256 * 1_024

    public static func validate(_ configuration: MicroConfiguration) throws {
        try validateSchema(configuration)
        try validateLayers(configuration.layers)
        try validateApplicationRules(configuration.applicationLayerRules)
        try validateJoystick(configuration.joystick)
    }

    private static func validateSchema(_ configuration: MicroConfiguration) throws {
        guard configuration.schemaVersion == MicroConfiguration.currentSchemaVersion else {
            throw failure("Unsupported schema version \(configuration.schemaVersion).")
        }
    }

    private static func validateLayers(_ layers: [LayerConfiguration]) throws {
        guard layers.count == LayerIndex.softwareLayerCount else {
            throw failure("The configuration must contain exactly ten layers.")
        }
        let identifiers = Set(layers.map(\.id))
        guard identifiers.count == layers.count else {
            throw failure("Layer identifiers must be unique.")
        }
        guard identifiers == Set(LayerIndex.all) else {
            throw failure("Every supported layer identifier must be present.")
        }
        for layer in layers { try validate(layer) }
    }

    private static func validate(_ layer: LayerConfiguration) throws {
        let name = layer.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.utf8.count <= 128 else {
            throw failure("Each layer name must contain between 1 and 128 bytes.")
        }
        guard layer.bindings.count <= ControlID.allCases.count else {
            throw failure("A layer contains too many bindings.")
        }
        for (control, action) in layer.bindings {
            try validate(action, for: control)
        }
        if let joystick = layer.joystick { try validateJoystick(joystick) }
    }

    private static func validateApplicationRules(
        _ rules: [ApplicationLayerRule]
    ) throws {
        guard rules.count <= LayerIndex.softwareLayerCount else {
            throw failure("At most ten application layer rules are supported.")
        }
        guard Set(rules.map(\.bundleIdentifier)).count == rules.count,
            Set(rules.map(\.layer)).count == rules.count
        else {
            throw failure("Application layer rules must be unique.")
        }
        for rule in rules { try validateBundleIdentifier(rule.bundleIdentifier) }
    }

    private static func validateJoystick(_ joystick: JoystickConfiguration) throws {
        try validateJoystickValues(
            deadZone: joystick.deadZone,
            maximumSpeed: joystick.maximumSpeed
        )
    }

    private static func validateJoystick(
        _ joystick: LayerJoystickConfiguration
    ) throws {
        try validateJoystickValues(
            deadZone: joystick.deadZone,
            maximumSpeed: joystick.maximumSpeed
        )
    }

    private static func validateJoystickValues(
        deadZone: Double,
        maximumSpeed: Double
    ) throws {
        guard deadZone.isFinite,
            (0...0.95).contains(deadZone)
        else {
            throw failure("The joystick dead zone is out of range.")
        }
        guard maximumSpeed.isFinite,
            (100...4_000).contains(maximumSpeed)
        else {
            throw failure("The joystick speed is out of range.")
        }
    }

    private static func validate(
        _ action: CreatorAction,
        for control: ControlID
    ) throws {
        switch action {
        case .none:
            throw failure("Unassigned bindings must be omitted.")
        case .shortOrLongPress(let shortPress, let longPress):
            try validateDualPress(
                shortPress: shortPress,
                longPress: longPress,
                control: control
            )
        case .dictation(let binding):
            try validate(binding)
        case .openApplication(let bundleIdentifier):
            try validateBundleIdentifier(bundleIdentifier)
        case .textSnippet(let value):
            try validateLength(value, maximum: 8_192, label: "Text snippet")
        case .slashCommand(let command, _):
            try validateLength(command, maximum: 8_192, label: "Slash command")
        case .keyboardShortcut(let shortcut):
            try validate(shortcut)
        case .actionSequence(let actions):
            try validateSequence(actions, control: control)
        case .appleScript(let value), .shellCommand(let value):
            try validateLength(value, maximum: 16_384, label: "Script")
        case .agentFocus(let sessionID):
            try validateIdentifier(sessionID, maximum: 128, label: "Agent session")
        case .volume(.set(let value)):
            guard value.isFinite, (0...1).contains(value) else {
                throw failure("A fixed volume must be between zero and one.")
            }
        case .pointer(.move(let horizontal, let vertical)):
            guard (-10_000...10_000).contains(horizontal),
                (-10_000...10_000).contains(vertical)
            else {
                throw failure("A pointer movement exceeds the supported range.")
            }
        default:
            break
        }
    }

    private static func validateDualPress(
        shortPress: CreatorAction,
        longPress: CreatorAction,
        control: ControlID
    ) throws {
        guard !control.isEncoderRotation else {
            throw failure("Encoder rotations cannot use short and long press actions.")
        }
        try validateDualPressBranch(shortPress, control: control)
        try validateDualPressBranch(longPress, control: control)
    }

    private static func validateDualPressBranch(
        _ action: CreatorAction,
        control: ControlID
    ) throws {
        switch action {
        case .none:
            throw failure("Short and long press actions must both be assigned.")
        case .shortOrLongPress:
            throw failure("Short and long press actions cannot be nested.")
        default:
            try validate(action, for: control)
        }
    }

    private static func validate(_ binding: DictationBinding) throws {
        try validateIdentifier(
            binding.providerID.rawValue,
            maximum: 255,
            label: "Dictation provider"
        )
        guard let shortcut = binding.shortcut else { return }
        try validate(shortcut)
    }

    private static func validate(_ shortcut: KeyShortcut) throws {
        guard !shortcut.isEmpty,
            shortcut.mainKeys.count <= KeyShortcut.maximumMainKeyCount
        else {
            throw failure("A shortcut needs a modifier or up to eight main keys.")
        }
        for key in shortcut.mainKeys {
            try validateIdentifier(key.key, maximum: 32, label: "Shortcut key")
        }
        guard let displayName = shortcut.displayName else { return }
        try validateLength(displayName, maximum: 128, label: "Shortcut name")
        guard
            displayName.unicodeScalars.allSatisfy({
                !CharacterSet.controlCharacters.contains($0)
            })
        else {
            throw failure("Shortcut name contains unsupported control characters.")
        }
    }

    private static func validateSequence(
        _ actions: [CreatorAction],
        control: ControlID
    ) throws {
        guard (2...6).contains(actions.count) else {
            throw failure("An action sequence must contain between two and six steps.")
        }
        for action in actions {
            switch action {
            case .none, .dictation, .shortOrLongPress, .actionSequence,
                .layer, .appleScript, .shellCommand, .agentFocus, .focusNextAgent:
                throw failure("An action sequence contains an unsupported step.")
            default:
                try validate(action, for: control)
            }
        }
    }

    private static func validateBundleIdentifier(_ value: String) throws {
        try validateIdentifier(value, maximum: 255, label: "Bundle identifier")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-."))
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 2,
            components.allSatisfy({ !$0.isEmpty }),
            value.unicodeScalars.allSatisfy(allowed.contains)
        else {
            throw failure("A bundle identifier has an invalid format.")
        }
    }

    private static func validateIdentifier(
        _ value: String,
        maximum: Int,
        label: String
    ) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= maximum else {
            throw failure("\(label) must contain between 1 and \(maximum) bytes.")
        }
    }

    private static func validateLength(
        _ value: String,
        maximum: Int,
        label: String
    ) throws {
        guard value.utf8.count <= maximum else {
            throw failure("\(label) exceeds the \(maximum)-byte limit.")
        }
    }

    private static func failure(_ message: String) -> MicroConfigurationValidationFailure {
        MicroConfigurationValidationFailure(message: message)
    }
}
