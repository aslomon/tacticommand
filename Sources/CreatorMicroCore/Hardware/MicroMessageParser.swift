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
        switch method {
        case "v.oai.hid":
            return .input(try parseInput(data, decoder: decoder))
        case "v.oai.rad":
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
        guard let control = ControlID(rawValue: parameters.key) else {
            throw MicroMessageParserError.unknownControl(parameters.key)
        }
        if let index = parameters.agentIndex,
            !(0..<MicroProtocolConstants.agentKeyCount).contains(index)
        {
            throw MicroMessageParserError.invalidAgentIndex(index)
        }
        return MicroInputEvent(
            control: control,
            phase: try phase(control: control, activity: parameters.activity),
            rawActivity: parameters.activity,
            agentIndex: parameters.agentIndex
        )
    }

    private static func phase(
        control: ControlID,
        activity: Int
    ) throws -> MicroInputPhase {
        if control.isEncoderRotation {
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
        return RadialInputEvent(angle: parameters.angle, distance: parameters.distance)
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

public enum MicroCommandBuilder {
    public static func deviceStatusRequest(identifier: Int = 1) throws -> Data {
        try JSONEncoder().encode(
            StatusRequest(method: "device.status", identifier: identifier)
        )
    }
}

private struct MethodEnvelope: Decodable {
    let compactMethod: String?
    let standardMethod: String?

    var resolvedMethod: String? { compactMethod ?? standardMethod }

    enum CodingKeys: String, CodingKey {
        case compactMethod = "m"
        case standardMethod = "method"
    }
}

private struct ParametersEnvelope<Parameters: Decodable>: Decodable {
    let compactParameters: Parameters?
    let standardParameters: Parameters?

    var resolvedParameters: Parameters? {
        compactParameters ?? standardParameters
    }

    enum CodingKeys: String, CodingKey {
        case compactParameters = "p"
        case standardParameters = "params"
    }
}

private struct KeyParameters: Decodable {
    let key: String
    let activity: Int
    let agentIndex: Int?

    enum CodingKeys: String, CodingKey {
        case key = "k"
        case activity = "act"
        case agentIndex = "ag"
    }
}

private struct RadialParameters: Decodable {
    let angle: Double
    let distance: Double

    enum CodingKeys: String, CodingKey {
        case angle = "a"
        case distance = "d"
    }
}

private struct StatusResultEnvelope: Decodable {
    let result: StatusResult?
    let containsResult: Bool
    let deviceError: DeviceError?
    let identifier: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        containsResult = container.contains(.result)
        if containsResult, try !container.decodeNil(forKey: .result) {
            result = try container.decode(StatusResult.self, forKey: .result)
        } else {
            result = .acknowledgement
        }
        deviceError = try container.decodeIfPresent(DeviceError.self, forKey: .error)
        identifier = try container.decodeIfPresent(Int.self, forKey: .identifier)
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case identifier = "id"
        case result
    }
}

private enum StatusResult: Decodable {
    case status(DeviceStatus)
    case acknowledgement

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: StatusCodingKeys.self) else {
            self = .acknowledgement
            return
        }
        let hasStatusKey = StatusCodingKeys.allCases.contains { container.contains($0) }
        guard hasStatusKey else {
            self = .acknowledgement
            return
        }
        self = .status(try DeviceStatus(from: decoder))
    }

    private enum StatusCodingKeys: String, CodingKey, CaseIterable {
        case version
        case profileIndex = "profile_index"
        case layerIndex = "layer_index"
        case battery
        case isCharging = "is_charging"
    }
}

private struct DeviceError: Decodable {
    let code: Int
    let message: String

    var isEmptyInputResponse: Bool {
        code == 400 && message == "JSON error - EmptyInput"
    }
}

private struct ResponseIdentifierEnvelope: Decodable {
    let identifier: Int?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
    }
}

private struct StatusRequest: Encodable {
    let method: String
    let identifier: Int

    enum CodingKeys: String, CodingKey {
        case method = "m"
        case identifier = "id"
    }
}
