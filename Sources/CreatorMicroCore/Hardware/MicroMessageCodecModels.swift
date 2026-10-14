import Foundation

public enum MicroCommandBuilder {
    public static func deviceStatusRequest(identifier: Int = 1) throws -> Data {
        try JSONEncoder().encode(
            StatusRequest(method: "device.status", identifier: identifier)
        )
    }
}

struct MethodEnvelope: Decodable {
    let compactMethod: String?
    let standardMethod: String?

    var resolvedMethod: String? { compactMethod ?? standardMethod }

    enum CodingKeys: String, CodingKey {
        case compactMethod = "m"
        case standardMethod = "method"
    }
}

struct ParametersEnvelope<Parameters: Decodable>: Decodable {
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

struct KeyParameters: Decodable {
    let key: String
    let activity: Int
    let agentIndex: Int?

    enum CodingKeys: String, CodingKey {
        case key = "k"
        case activity = "act"
        case agentIndex = "ag"
    }
}

struct RadialParameters: Decodable {
    let angle: Double
    let distance: Double
    let operation: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operation = try container.decodeIfPresent(Int.self, forKey: .operation)
        if operation == 0 {
            angle = 0
            distance = 0
        } else {
            angle = try container.decode(Double.self, forKey: .angle)
            distance = try container.decode(Double.self, forKey: .distance)
        }
    }

    enum CodingKeys: String, CodingKey {
        case angle = "a"
        case distance = "d"
        case operation = "o"
    }
}

struct StatusResultEnvelope: Decodable {
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

enum StatusResult: Decodable {
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

struct DeviceError: Decodable {
    let code: Int
    let message: String

    var isEmptyInputResponse: Bool {
        code == 400 && message == "JSON error - EmptyInput"
    }
}

struct ErrorEnvelope: Decodable {
    let error: DeviceError?
}

struct ResponseIdentifierEnvelope: Decodable {
    let identifier: Int?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
    }
}

struct StatusRequest: Encodable {
    let method: String
    let identifier: Int

    enum CodingKeys: String, CodingKey {
        case method
        case parameters = "params"
        case identifier = "id"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(method, forKey: .method)
        try container.encodeNil(forKey: .parameters)
        try container.encode(identifier, forKey: .identifier)
    }
}
