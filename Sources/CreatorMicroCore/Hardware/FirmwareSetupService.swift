import Foundation

public struct FirmwareSetupInspection: Equatable, Sendable {
    public let token: UUID
    public let model: MicroDeviceModel
    public let rawLayer: Int
    public let layerName: String
    public let isReady: Bool
    public var canProvision: Bool { model == .creator13 && !isReady }
}

public actor FirmwareSetupService {
    private struct Snapshot: Sendable {
        let identity: DeviceIdentitySnapshot
        let bytes: Data
        let document: FirmwareKeymapDocument
    }
    private let client: any FirmwareSetupClient
    private let backups: any FirmwareBackupSaving
    private var inspection: (UUID, Snapshot)?
    private var original: Snapshot?
    private var busy = false
    public private(set) var backupURL: URL?

    public init(client: any FirmwareSetupClient, backups: any FirmwareBackupSaving = LocalFirmwareBackupStore()) {
        self.client = client
        self.backups = backups
    }

    public func inspect() async throws -> FirmwareSetupInspection {
        guard !busy else { throw FirmwareSetupError.inspectionExpired }
        busy = true
        defer { busy = false }
        inspection = nil
        let snapshot = try await readSnapshot()
        let token = UUID()
        inspection = (token, snapshot)
        return summary(token: token, snapshot: snapshot)
    }

    public func provision(token: UUID, consent: Bool) async throws {
        guard consent else { throw FirmwareSetupError.consentRequired }
        guard !busy, let (savedToken, saved) = inspection, savedToken == token else {
            throw FirmwareSetupError.inspectionExpired
        }
        guard saved.identity.capability.model == .creator13 else { throw FirmwareSetupError.unsupported }
        busy = true
        defer { busy = false }
        inspection = nil
        let fresh = try await readSnapshot()
        try requireSameTarget(saved, fresh)
        guard fresh.document.value == saved.document.value else { throw FirmwareSetupError.changedDevice }
        if fresh.document.isCreatorReady { return }
        let intended = try fresh.document.preparedCreator()
        backupURL = try await backups.save(
            fresh.bytes, identity: fresh.identity, profile: fresh.document.profileID, rawLayer: fresh.document.rawLayer)
        original = fresh
        // Recheck after the asynchronous backup, immediately before the firmware mutation.
        let checked = try await readSnapshot()
        try requireSameTarget(fresh, checked)
        guard checked.document.value == fresh.document.value else { throw FirmwareSetupError.changedDevice }
        try await writeAndVerify(intended, snapshot: checked)
    }

    public func restore(consent: Bool) async throws {
        guard consent else { throw FirmwareSetupError.consentRequired }
        guard !busy, let original else { throw FirmwareSetupError.noBackup }
        busy = true
        defer { busy = false }
        inspection = nil
        let fresh = try await readSnapshot()
        try requireSameTarget(original, fresh)
        let intended = try fresh.document.replacingLayer(original.document.layer)
        backupURL = try await backups.save(
            fresh.bytes, identity: fresh.identity, profile: fresh.document.profileID, rawLayer: fresh.document.rawLayer)
        let checked = try await readSnapshot()
        try requireSameTarget(fresh, checked)
        guard checked.document.value == fresh.document.value else { throw FirmwareSetupError.changedDevice }
        try await writeAndVerify(intended, snapshot: checked)
        self.original = nil
    }

    public func canRestore() async -> Bool {
        guard let original, let identity = await client.identity() else { return false }
        return identity.connectionID == original.identity.connectionID
    }

    private func readSnapshot() async throws -> Snapshot {
        guard let identity = await client.identity() else { throw MicroConnectionError.notConnected }
        guard identity.capability.model != .unknown else { throw FirmwareSetupError.unsupported }
        let status = try await client.call("device.status", parameters: .null, connection: identity.connectionID)
        guard let rawLayer = status["layer_index"]?.integer else { throw FirmwareSetupError.invalidDocument }
        let result = try await client.call(
            "fs.read", parameters: .object(["file": .string("keymap.json")]), connection: identity.connectionID)
        guard let text = result["data"]?.string, text.utf8.count <= FirmwareKeymapDocument.maximumBytes else {
            throw FirmwareSetupError.invalidDocument
        }
        guard await client.identity() == identity else { throw FirmwareSetupError.changedDevice }
        let bytes = Data(text.utf8)
        return Snapshot(
            identity: identity, bytes: bytes, document: try FirmwareKeymapDocument(data: bytes, rawLayer: rawLayer))
    }

    private func requireSameTarget(_ lhs: Snapshot, _ rhs: Snapshot) throws {
        guard lhs.identity == rhs.identity, lhs.document.profileID == rhs.document.profileID,
            lhs.document.rawLayer == rhs.document.rawLayer,
            lhs.document.layer["id"] == rhs.document.layer["id"]
        else { throw FirmwareSetupError.changedDevice }
    }

    private func writeAndVerify(_ intended: Data, snapshot: Snapshot) async throws {
        try Task.checkCancellation()
        let status = try await client.call(
            "device.status", parameters: .null, connection: snapshot.identity.connectionID)
        guard status["layer_index"]?.integer == snapshot.document.rawLayer,
            await client.identity() == snapshot.identity
        else { throw FirmwareSetupError.changedDevice }
        guard let text = String(data: intended, encoding: .utf8) else { throw FirmwareSetupError.invalidDocument }
        _ = try await client.call(
            "fs.write",
            parameters: .object([
                "file": .string("keymap.json"), "data": .string(text),
            ]), connection: snapshot.identity.connectionID)
        let readback = try await readSnapshot()
        try requireSameTarget(snapshot, readback)
        guard readback.document.value == (try JSONDecoder().decode(MicroJSONValue.self, from: intended)) else {
            throw FirmwareSetupError.readbackMismatch
        }
    }

    private func summary(token: UUID, snapshot: Snapshot) -> FirmwareSetupInspection {
        FirmwareSetupInspection(
            token: token, model: snapshot.identity.capability.model,
            rawLayer: snapshot.document.rawLayer, layerName: snapshot.document.layerName,
            isReady: snapshot.identity.capability.model == .creator13
                ? snapshot.document.isCreatorReady : snapshot.document.isCodexReady)
    }
}
