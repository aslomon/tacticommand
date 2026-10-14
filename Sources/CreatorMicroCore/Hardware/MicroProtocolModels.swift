import Foundation

public enum MicroProtocolConstants {
    public static let vendorIdentifier = 0x303A
    public static let productIdentifier = 0x8360
    public static let creatorMicroProductIdentifiers: Set<Int> = [0x8297, 0x8298]
    public static let supportedProductIdentifiers: Set<Int> =
        Set([productIdentifier]).union(creatorMicroProductIdentifiers)
    public static let vendorUsagePage = 0xFF00
    public static let reportIdentifier: UInt8 = 0x06
    public static let dataOpcode: UInt8 = 0x02
    public static let usbReportLength = 63
    public static let bluetoothReportLength = 64
    public static let maximumChunkLength = 61
    public static let agentKeyCount = 6
    public static let layerCount = 6
}

public enum MicroTransportKind: String, Codable, Hashable, Sendable {
    case usb
    case bluetoothLowEnergy

    public init?(ioKitValue: String) {
        switch ioKitValue {
        case "USB":
            self = .usb
        case "Bluetooth Low Energy":
            self = .bluetoothLowEnergy
        default:
            return nil
        }
    }
}

public enum ControlID: String, CaseIterable, Codable, Hashable, Sendable {
    case agent0 = "AG00"
    case agent1 = "AG01"
    case agent2 = "AG02"
    case agent3 = "AG03"
    case agent4 = "AG04"
    case agent5 = "AG05"
    case action6 = "ACT06"
    case action7 = "ACT07"
    case action8 = "ACT08"
    case action9 = "ACT09"
    case action10 = "ACT10"
    case action11 = "ACT11"
    case action12 = "ACT12"
    case encoderPress = "ENC_CLK"
    case encoderClockwise = "ENC_CW"
    case encoderCounterClockwise = "ENC_CC"

    public var isEncoderRotation: Bool {
        self == .encoderClockwise || self == .encoderCounterClockwise
    }

    public var agentIndex: Int? {
        switch self {
        case .agent0: 0
        case .agent1: 1
        case .agent2: 2
        case .agent3: 3
        case .agent4: 4
        case .agent5: 5
        default: nil
        }
    }
}

public enum MicroInputPhase: String, Codable, Hashable, Sendable {
    case pressed
    case released
    case pulse
}

public struct MicroInputEvent: Codable, Hashable, Sendable {
    public let control: ControlID
    public let phase: MicroInputPhase
    public let rawActivity: Int
    public let agentIndex: Int?

    public init(
        control: ControlID,
        phase: MicroInputPhase,
        rawActivity: Int,
        agentIndex: Int?
    ) {
        self.control = control
        self.phase = phase
        self.rawActivity = rawActivity
        self.agentIndex = agentIndex
    }
}

public struct RadialInputEvent: Codable, Hashable, Sendable {
    public let angle: Double
    public let distance: Double

    public init(angle: Double, distance: Double) {
        self.angle = angle
        self.distance = distance
    }
}

public struct DeviceStatus: Codable, Hashable, Sendable {
    public let version: String?
    public let profileIndex: Int?
    public let layerIndex: Int?
    public let batteryPercentage: Int?
    public let isCharging: Bool?

    public init(
        version: String? = nil,
        profileIndex: Int? = nil,
        layerIndex: Int? = nil,
        batteryPercentage: Int? = nil,
        isCharging: Bool? = nil
    ) {
        self.version = version
        self.profileIndex = profileIndex
        self.layerIndex = layerIndex
        self.batteryPercentage = batteryPercentage
        self.isCharging = isCharging
    }

    public var hasReportedValue: Bool {
        version != nil || profileIndex != nil || layerIndex != nil
            || batteryPercentage != nil || isCharging != nil
    }

    enum CodingKeys: String, CodingKey {
        case version
        case profileIndex = "profile_index"
        case layerIndex = "layer_index"
        case batteryPercentage = "battery"
        case isCharging = "is_charging"
    }
}

public enum MicroDeviceEvent: Equatable, Sendable {
    case input(MicroInputEvent)
    case radial(RadialInputEvent)
    case status(DeviceStatus)
    case unhandled(method: String?)
}

/// Real, observed device identity for the active connection. Carried separately from
/// `DeviceConnectionState` so adding capability metadata never forces every existing
/// `connected(transport:status:)` switch to change.
public struct DeviceIdentitySnapshot: Equatable, Sendable {
    /// Session-scoped guard: backups cannot be restored to a different connection.
    public let connectionID: UUID
    public let transport: MicroTransportKind
    public let productIdentifier: Int?
    public let capability: DeviceCapabilityProfile

    public init(transport: MicroTransportKind, productIdentifier: Int?, connectionID: UUID = UUID()) {
        self.connectionID = connectionID
        self.transport = transport
        self.productIdentifier = productIdentifier
        self.capability = DeviceCapabilityProfile(productIdentifier: productIdentifier)
    }
}

public enum DeviceConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected(transport: MicroTransportKind, status: DeviceStatus?)
    case unavailable(reason: String)
}
