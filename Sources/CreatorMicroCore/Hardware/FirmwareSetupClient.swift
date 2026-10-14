import Foundation

public protocol FirmwareSetupClient: Sendable {
    func identity() async -> DeviceIdentitySnapshot?
    func call(_ method: String, parameters: MicroJSONValue, connection: UUID) async throws -> MicroJSONValue
}

public struct CoordinatorFirmwareSetupClient: FirmwareSetupClient {
    public let coordinator: MicroDeviceCoordinator
    public init(coordinator: MicroDeviceCoordinator) { self.coordinator = coordinator }
    public func identity() async -> DeviceIdentitySnapshot? { await coordinator.identitySnapshot }
    public func call(_ method: String, parameters: MicroJSONValue, connection: UUID) async throws -> MicroJSONValue {
        try await coordinator.request(method: method, parameters: parameters, expectedConnection: connection)
    }
}

public protocol FirmwareBackupSaving: Sendable {
    func save(_ bytes: Data, identity: DeviceIdentitySnapshot, profile: Int, rawLayer: Int) async throws -> URL
}

public actor LocalFirmwareBackupStore: FirmwareBackupSaving {
    private let root: URL
    public init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TactiCommand/Backups", isDirectory: true)
    ) { self.root = root }

    public func save(_ bytes: Data, identity: DeviceIdentitySnapshot, profile: Int, rawLayer: Int) throws -> URL {
        let directory = root.appendingPathComponent("setup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = directory.appendingPathComponent("keymap.json")
        try bytes.write(to: file, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        let metadata = try MicroJSONValue.object([
            "connection": .string(identity.connectionID.uuidString),
            "product": identity.productIdentifier.map { .number(Decimal($0)) } ?? .null,
            "profile": .number(Decimal(profile)), "rawLayer": .number(Decimal(rawLayer)),
        ]).encoded()
        let metadataURL = directory.appendingPathComponent("metadata.json")
        try metadata.write(to: metadataURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: metadataURL.path)
        guard try Data(contentsOf: file) == bytes else { throw FirmwareSetupError.invalidDocument }
        return file
    }
}
