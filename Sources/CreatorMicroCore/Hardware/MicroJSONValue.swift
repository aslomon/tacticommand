import Foundation

/// Lossless JSON structure for firmware documents, including fields unknown to this app.
public enum MicroJSONValue: Codable, Equatable, Sendable {
    case object([String: MicroJSONValue])
    case array([MicroJSONValue])
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: Self].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([Self].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public subscript(_ key: String) -> Self? {
        guard case .object(let fields) = self else { return nil }
        return fields[key]
    }
    public var string: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }
    public var integer: Int? {
        guard case .number(let value) = self,
            let integer = Int(NSDecimalNumber(decimal: value).stringValue)
        else { return nil }
        return integer
    }
    public var array: [Self]? {
        guard case .array(let value) = self else { return nil }
        return value
    }
    public func replacing(_ key: String, with value: Self) throws -> Self {
        guard case .object(var fields) = self else { throw MicroRPCError.malformedResponse }
        fields[key] = value
        return .object(fields)
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
