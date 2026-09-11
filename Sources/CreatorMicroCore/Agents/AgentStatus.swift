import Foundation

public struct AgentDeviceLight: Codable, Equatable, Hashable, Sendable {
    public static let off = AgentDeviceLight(hex: "#000000", brightness: 0)

    public let hex: String
    public let brightness: Double

    public init(hex: String, brightness: Double) {
        self.hex = hex
        self.brightness = brightness
    }
}

public enum AgentStatus: String, CaseIterable, Equatable, Hashable, Sendable {
    case idle
    case working
    case waiting
    case complete
    case error
    case unavailable

    public var deviceLight: AgentDeviceLight {
        switch self {
        case .idle:
            AgentDeviceLight(hex: "#FFFFFF", brightness: 1)
        case .working:
            AgentDeviceLight(hex: "#304FFE", brightness: 1)
        case .waiting:
            AgentDeviceLight(hex: "#FF6D00", brightness: 1)
        case .complete:
            AgentDeviceLight(hex: "#00FF4C", brightness: 1)
        case .error:
            AgentDeviceLight(hex: "#FF0033", brightness: 1)
        case .unavailable:
            .off
        }
    }

    public var priority: Int {
        switch self {
        case .unavailable: 0
        case .idle: 1
        case .working: 2
        case .complete: 3
        case .error: 4
        case .waiting: 5
        }
    }

    public var needsAttention: Bool {
        switch self {
        case .waiting, .complete, .error:
            true
        case .idle, .working, .unavailable:
            false
        }
    }
}

extension AgentStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "idle": self = .idle
        case "working", "running": self = .working
        case "waiting", "requires_action": self = .waiting
        case "complete", "completed", "done", "succeeded": self = .complete
        case "error", "failed": self = .error
        default: self = .unavailable
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
