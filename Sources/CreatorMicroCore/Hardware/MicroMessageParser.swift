import Foundation

public enum MicroMessageParserError: Error, Equatable, LocalizedError {
    case missingMethod
    case missingParameters(method: String)
    case deviceError(code: Int, message: String)
    case unknownControl(String)
    case invalidActivity(Int)
    case invalidAgentIndex(Int)
    case invalidRadialValue(field: String, value: Double)

    public var errorDescription: String? {
        switch self {
        case .missingMethod:
            "The device message has no method or recognizable status result."
        case .missingParameters(let method):
            "The device message for \(method) has no parameters."
        case .deviceError(let code, let message):
            "The device reported error \(code): \(message)"
        case .unknownControl(let identifier):
            "The device reported an unknown control: \(identifier)."
        case .invalidActivity(let value):
            "A physical key reported unsupported activity value \(value)."
        case .invalidAgentIndex(let index):
            "The device reported invalid agent index \(index)."
        case .invalidRadialValue(let field, let value):
            "Radial value \(field) must be between 0 and 1, got \(value)."
        }
    }
}

public enum MicroMessageParser {
    public static func responseIdentifier(_ data: Data) -> Int? {
        try? JSONDecoder().decode(ResponseIdentifierEnvelope.self, from: data).identifier
    }

    public static func parse(_ data: Data) throws -> MicroDeviceEvent {
        let decoder = JSONDecoder()
        let methodEnvelope = try decoder.decode(MethodEnvelope.self, from: data)
        guard let method = methodEnvelope.resolvedMethod else {
            return try parseStatusResult(data, decoder: decoder)
        }
        if let error = try decoder.decode(ErrorEnvelope.self, from: data).error {
            if error.isEmptyInputResponse, responseIdentifier(data) == nil {
                return .unhandled(method: "response.error")
            }
            throw MicroMessageParserError.deviceError(code: error.code, message: error.message)
        }
        switch method {
        case "v.oai.hid":
            return .input(try parseInput(data, decoder: decoder))
        case "v.oai.rad", "kb.radial":
            return .radial(try parseRadial(data, decoder: decoder))
        case "device.status":
            return .status(try parseStatusPayload(data, decoder: decoder))
        default:
            return .unhandled(method: method)
        }
    }

    private static func parseInput(
        _ data: Data,
        decoder: JSONDecoder
    ) throws -> MicroInputEvent {
        let envelope = try decoder.decode(ParametersEnvelope<KeyParameters>.self, from: data)
        guard let parameters = envelope.resolvedParameters else {
            throw MicroMessageParserError.missingParameters(method: "v.oai.hid")
        }
        let nativeControl = ControlID(rawValue: parameters.key)
        guard let control = nativeControl ?? creatorControl(parameters.key) else {
            throw MicroMessageParserError.unknownControl(parameters.key)
        }
        if let index = parameters.agentIndex,
            !(0..<MicroProtocolConstants.agentKeyCount).contains(index)
        {
            throw MicroMessageParserError.invalidAgentIndex(index)
        }
        // AG13/AG14 are Creator's discrete press/release aliases for the encoder, routed onto
        // the same ControlID as Codex's native continuous-tick ENC_CW/ENC_CC. Only the native
        // key must always pulse; the alias must respect activity or it fires on both edges.
        let isCreatorEncoderAlias = nativeControl == nil && control.isEncoderRotation
        return MicroInputEvent(
            control: control,
            phase: try phase(
                control: control,
                activity: parameters.activity,
                treatAsDiscreteKey: isCreatorEncoderAlias
            ),
            rawActivity: parameters.activity,
            agentIndex: parameters.agentIndex
        )
    }

    private static func creatorControl(_ key: String) -> ControlID? {
        switch key {
        case "AG06": .action6
        case "AG07": .action7
        case "AG08": .action8
        case "AG09": .action9
        case "AG10": .action10
        case "AG11": .action11
        case "AG12": .action12
        case "AG13": .encoderClockwise
        case "AG14": .encoderCounterClockwise
        case "AG15": .encoderPress
        default: nil
        }
    }

    private static func phase(
        control: ControlID,
        activity: Int,
        treatAsDiscreteKey: Bool
    ) throws -> MicroInputPhase {
        if control.isEncoderRotation && !treatAsDiscreteKey {
            return .pulse
        }
        switch activity {
        case 0: return .released
        case 1: return .pressed
        default: throw MicroMessageParserError.invalidActivity(activity)
        }
    }

    private static func parseRadial(
        _ data: Data,
        decoder: JSONDecoder
    ) throws -> RadialInputEvent {
        let envelope = try decoder.decode(
            ParametersEnvelope<RadialParameters>.self,
            from: data
        )
        guard let parameters = envelope.resolvedParameters else {
            throw MicroMessageParserError.missingParameters(method: "v.oai.rad")
        }
        try validateUnit(parameters.angle, field: "angle")
        try validateUnit(parameters.distance, field: "distance")
        return RadialInputEvent(
            angle: parameters.angle,
            distance: parameters.operation == 0 ? 0 : parameters.distance)
    }

    private static func validateUnit(_ value: Double, field: String) throws {
        guard value.isFinite, (0...1).contains(value) else {
            throw MicroMessageParserError.invalidRadialValue(field: field, value: value)
        }
    }

    private static func parseStatusParameters(
        _ data: Data,
        decoder: JSONDecoder
    ) throws -> DeviceStatus {
        let envelope = try decoder.decode(
            ParametersEnvelope<DeviceStatus>.self,
            from: data
        )
        guard let status = envelope.resolvedParameters else {
            throw MicroMessageParserError.missingParameters(method: "device.status")
        }
        return status
    }

    private static func parseStatusPayload(
        _ data: Data,
        decoder: JSONDecoder
    ) throws -> DeviceStatus {
        let resultEnvelope = try decoder.decode(StatusResultEnvelope.self, from: data)
        if let error = resultEnvelope.deviceError {
            throw MicroMessageParserError.deviceError(code: error.code, message: error.message)
        }
        if case .status(let status) = resultEnvelope.result, status.hasReportedValue {
            return status
        }
        return try parseStatusParameters(data, decoder: decoder)
    }

    private static func parseStatusResult(
        _ data: Data,
        decoder: JSONDecoder
    ) throws -> MicroDeviceEvent {
        let envelope = try decoder.decode(StatusResultEnvelope.self, from: data)
        if let deviceError = envelope.deviceError {
            guard deviceError.isEmptyInputResponse, envelope.identifier == nil else {
                throw MicroMessageParserError.deviceError(
                    code: deviceError.code,
                    message: deviceError.message
                )
            }
            return .unhandled(method: "response.error")
        }
        if case .status(let status) = envelope.result, status.hasReportedValue {
            return .status(status)
        }
        if envelope.containsResult {
            return .unhandled(method: "response")
        }
        throw MicroMessageParserError.missingMethod
    }
}
