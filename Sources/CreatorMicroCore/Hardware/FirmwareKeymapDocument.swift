import Foundation

public enum FirmwareSetupError: Error, Equatable, LocalizedError {
    case unsupported, invalidDocument, consentRequired, inspectionExpired, changedDevice, readbackMismatch, noBackup
    public var errorDescription: String? {
        switch self {
        case .unsupported: "This device cannot be configured automatically. Use its official configurator."
        case .invalidDocument: "The firmware keymap or active physical layer is invalid. No changes were made."
        case .consentRequired: "Confirm the active-layer replacement before continuing."
        case .inspectionExpired: "Inspect the device again before making changes."
        case .changedDevice: "The device, physical layer or keymap changed. Inspect again."
        case .readbackMismatch:
            "The saved keymap could not be verified. Your backup is retained; do not repeat the write blindly."
        case .noBackup: "No safe backup is available for this connection. Existing backup files remain on disk."
        }
    }
}

public struct FirmwareKeymapDocument: Sendable {
    // Fits the 64 KiB receive frame limit even when the RPC JSON string is escaped.
    public static let maximumBytes = 16 * 1_024
    public let value: MicroJSONValue
    public let profileID: Int
    public let rawLayer: Int
    public let layers: [MicroJSONValue]
    private let profileOffset: Int
    private let profiles: [MicroJSONValue]

    public init(data: Data, rawLayer: Int) throws {
        guard data.count <= Self.maximumBytes,
            let value = try? JSONDecoder().decode(MicroJSONValue.self, from: data),
            let active = value["activeProfileId"]?.integer,
            let profiles = value["profiles"]?.array,
            profiles.filter({ $0["id"]?.integer == active }).count == 1,
            let offset = profiles.firstIndex(where: { $0["id"]?.integer == active }),
            let layers = profiles[offset]["layers"]?.array,
            (1...max(1, layers.count)).contains(rawLayer), rawLayer <= layers.count,
            layers[rawLayer - 1]["id"]?.integer != nil,
            layers[rawLayer - 1]["name"]?.string != nil,
            case .object = layers[rawLayer - 1]["layout"]
        else { throw FirmwareSetupError.invalidDocument }
        self.value = value
        self.profileID = active
        self.profiles = profiles
        self.profileOffset = offset
        self.rawLayer = rawLayer
        self.layers = layers
    }

    public var layer: MicroJSONValue { layers[rawLayer - 1] }
    public var layerName: String { layer["name"]?.string ?? "Unknown" }
    public var isCreatorReady: Bool {
        layer["layout"]?["keymap"] == Self.creatorKeys
            && layer["layout"]?["encoders"] == Self.creatorEncoder
            && layer["layout"]?["joystick"]?["type"] == .string("RADIAL")
            && layer["layout"]?["joystick"]?["sectors"] == .array([])
    }
    public var isCodexReady: Bool {
        let keys = layer["layout"]?["keymap"]?.array?.flatMap { $0.array ?? [] }.compactMap(\.string) ?? []
        let encoder = layer["layout"]?["encoders"]?.array?.flatMap { $0.array ?? [] }.compactMap(\.string) ?? []
        let expected =
            (0..<6).map { String(format: "KV_OAI_AG%02d", $0) }
            + (6..<13).map { String(format: "KV_OAI_ACT%02d", $0) }
        return keys == expected
            && encoder == ["KV_OAI_ENC_CW", "KV_OAI_ENC_CC", "KV_OAI_ENC_CLK"]
            && layer["layout"]?["joystick"]?["type"] == .string("RADIAL")
            && layer["layout"]?["joystick"]?["sectors"] == .array([])
    }

    public func preparedCreator() throws -> Data {
        guard var layout = layer["layout"] else { throw FirmwareSetupError.invalidDocument }
        layout = try layout.replacing("keymap", with: Self.creatorKeys)
        layout = try layout.replacing("encoders", with: Self.creatorEncoder)
        let joystick = layout["joystick"] ?? .object([:])
        layout = try layout.replacing(
            "joystick",
            with:
                joystick.replacing("type", with: .string("RADIAL")).replacing("sectors", with: .array([])))
        return try replacingLayer(
            layer.replacing("layout", with: layout).replacing("name", with: .string("TactiCommand")))
    }

    public func replacingLayer(_ replacement: MicroJSONValue) throws -> Data {
        guard replacement["id"] == layer["id"] else { throw FirmwareSetupError.changedDevice }
        var layers = layers
        layers[rawLayer - 1] = replacement
        var profiles = profiles
        profiles[profileOffset] = try profiles[profileOffset].replacing("layers", with: .array(layers))
        return try value.replacing("profiles", with: .array(profiles)).encoded()
    }

    private static let creatorKeys: MicroJSONValue = .array(
        [[0, 1], [2, 3, 4, 5], [6, 7, 8, 9], [10, 11, 12]].map { row in
            .array(row.map { .string(String(format: "KV_OAI_AG%02d", $0)) })
        })
    private static let creatorEncoder: MicroJSONValue = .array([
        .array((13...15).map { .string(String(format: "KV_OAI_AG%02d", $0)) })
    ])
}
