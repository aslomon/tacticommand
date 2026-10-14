import Foundation
import XCTest

@testable import CreatorMicroCore

final class FirmwareSetupServiceTests: XCTestCase {
    func testInspectionAndDeniedConsentNeverWrite() async throws {
        let client = FakeFirmwareClient()
        let backups = FakeFirmwareBackups()
        let service = FirmwareSetupService(client: client, backups: backups)
        let inspection = try await service.inspect()
        XCTAssertEqual(inspection.rawLayer, 2)
        XCTAssertTrue(inspection.canProvision)
        do {
            try await service.provision(token: inspection.token, consent: false)
            XCTFail()
        } catch FirmwareSetupError.consentRequired {}
        let writes = await client.writes
        let saves = await backups.saves
        XCTAssertEqual(writes, 0)
        XCTAssertEqual(saves, [])
    }

    func testBackupFailurePreventsWrite() async throws {
        let client = FakeFirmwareClient()
        let service = FirmwareSetupService(client: client, backups: FakeFirmwareBackups(fails: true))
        let inspection = try await service.inspect()
        do {
            try await service.provision(token: inspection.token, consent: true)
            XCTFail()
        } catch FirmwareSetupError.noBackup {}
        let writes = await client.writes
        XCTAssertEqual(writes, 0)
    }

    func testDriftBeforeWritePreventsMutation() async throws {
        for change in [FakeFirmwareClient.Change.connection, .layer, .document] {
            let client = FakeFirmwareClient()
            let service = FirmwareSetupService(client: client, backups: FakeFirmwareBackups())
            let inspection = try await service.inspect()
            await client.change(change)
            do {
                try await service.provision(token: inspection.token, consent: true)
                XCTFail()
            } catch FirmwareSetupError.changedDevice {}
            let writes = await client.writes
            XCTAssertEqual(writes, 0)
        }
    }

    func testProvisionBacksUpOriginalBytesAndVerifiesWholeDocument() async throws {
        let client = FakeFirmwareClient()
        let backups = FakeFirmwareBackups()
        let service = FirmwareSetupService(client: client, backups: backups)
        let inspection = try await service.inspect()
        try await service.provision(token: inspection.token, consent: true)
        let saves = await backups.saves
        XCTAssertEqual(saves.first, FirmwareKeymapDocumentTests.fixture)
        let updated = try await service.inspect()
        XCTAssertTrue(updated.isReady)
        let canRestore = await service.canRestore()
        XCTAssertTrue(canRestore)
    }

    func testAcknowledgementWithoutReadbackIsNotSuccess() async throws {
        let client = FakeFirmwareClient(ignoreWrite: true)
        let service = FirmwareSetupService(client: client, backups: FakeFirmwareBackups())
        let inspection = try await service.inspect()
        do {
            try await service.provision(token: inspection.token, consent: true)
            XCTFail()
        } catch FirmwareSetupError.readbackMismatch {}
        let backup = await service.backupURL
        XCTAssertNotNil(backup)
    }

    func testRestorePreservesLaterChangesOutsideTargetAndBacksUpCurrentBytes() async throws {
        let client = FakeFirmwareClient()
        let backups = FakeFirmwareBackups()
        let service = FirmwareSetupService(client: client, backups: backups)
        let inspection = try await service.inspect()
        try await service.provision(token: inspection.token, consent: true)
        await client.change(.document)
        let beforeRestore = await client.bytes
        try await service.restore(consent: true)
        let after = try await JSONDecoder().decode(MicroJSONValue.self, from: client.bytes)
        XCTAssertEqual(after["unknown"], .string("later"))
        let document = try FirmwareKeymapDocument(data: await client.bytes, rawLayer: 2)
        let original = try FirmwareKeymapDocument(data: FirmwareKeymapDocumentTests.fixture, rawLayer: 2)
        XCTAssertEqual(document.layer, original.layer)
        let saves = await backups.saves
        XCTAssertEqual(saves.last, beforeRestore)
    }

    func testRestoreToSamePIDReplacementIsRejected() async throws {
        let client = FakeFirmwareClient()
        let service = FirmwareSetupService(client: client, backups: FakeFirmwareBackups())
        let inspection = try await service.inspect()
        try await service.provision(token: inspection.token, consent: true)
        await client.change(.connection)
        do {
            try await service.restore(consent: true)
            XCTFail()
        } catch FirmwareSetupError.changedDevice {}
        let writes = await client.writes
        XCTAssertEqual(writes, 1)
    }
}

private actor FakeFirmwareClient: FirmwareSetupClient {
    enum Change { case connection, layer, document }
    var observed = DeviceIdentitySnapshot(transport: .usb, productIdentifier: 0x8298)
    var bytes = FirmwareKeymapDocumentTests.fixture
    var layer = 2
    var writes = 0
    let ignoreWrite: Bool
    init(ignoreWrite: Bool = false) { self.ignoreWrite = ignoreWrite }
    func identity() -> DeviceIdentitySnapshot? { observed }
    func change(_ change: Change) {
        switch change {
        case .connection: observed = DeviceIdentitySnapshot(transport: .usb, productIdentifier: 0x8298)
        case .layer: layer = 1
        case .document:
            let value = try! JSONDecoder().decode(MicroJSONValue.self, from: bytes)
            bytes = try! value.replacing("unknown", with: .string("later")).encoded()
        }
    }
    func call(_ method: String, parameters: MicroJSONValue, connection: UUID) throws -> MicroJSONValue {
        guard connection == observed.connectionID else { throw MicroConnectionError.notConnected }
        switch method {
        case "device.status": return .object(["layer_index": .number(Decimal(layer))])
        case "fs.read": return .object(["data": .string(String(decoding: bytes, as: UTF8.self))])
        case "fs.write":
            writes += 1
            if !ignoreWrite, let text = parameters["data"]?.string { bytes = Data(text.utf8) }
            return .null
        default: throw MicroRPCError.malformedResponse
        }
    }
}

private actor FakeFirmwareBackups: FirmwareBackupSaving {
    var saves: [Data] = []
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    func save(_ bytes: Data, identity: DeviceIdentitySnapshot, profile: Int, rawLayer: Int) throws -> URL {
        if fails { throw FirmwareSetupError.noBackup }
        saves.append(bytes)
        return URL(fileURLWithPath: "/tmp/test-only-keymap.json")
    }
}
