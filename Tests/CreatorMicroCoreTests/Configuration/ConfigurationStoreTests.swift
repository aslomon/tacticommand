import Foundation
import XCTest

@testable import CreatorMicroCore

final class ConfigurationStoreTests: XCTestCase {
    func testMissingFileLoadsDefaultConfiguration() async throws {
        let location = makeTemporaryConfigurationDirectory().appendingPathComponent("config.json")
        let store = ConfigurationStore(fileURL: location)

        let result = await store.load()
        let configuration = try result.get()

        XCTAssertEqual(configuration, .default)
    }

    func testSavedConfigurationLoadsFromDisk() async throws {
        let location = makeTemporaryConfigurationDirectory().appendingPathComponent("config.json")
        let store = ConfigurationStore(fileURL: location)
        var expected = MicroConfiguration.default
        expected.assign(action: .openFinder, to: .agent0, on: .windows)

        try await store.save(expected).get()
        let loaded = try await store.load().get()

        XCTAssertEqual(loaded, expected)
    }

    func testMigrationPreservesExactOriginalBytesInAPrivateBackup() async throws {
        let directory = makeTemporaryConfigurationDirectory()
        let location = directory.appendingPathComponent("configuration.json")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 7
        let original = try JSONEncoder().encode(legacy)
        try original.write(to: location)
        let store = ConfigurationStore(fileURL: location)

        _ = try await store.load().get()

        let backup = directory.appendingPathComponent("configuration.v7.backup.json")
        XCTAssertEqual(try Data(contentsOf: backup), original)
        let attributes = try FileManager.default.attributesOfItem(atPath: backup.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o600)
    }

    func testMalformedConfigurationReturnsAReadableFailure() async throws {
        let directory = makeTemporaryConfigurationDirectory()
        let location = directory.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: location)
        let store = ConfigurationStore(fileURL: location)

        let result = await store.load()

        guard case .failure(let error) = result else {
            return XCTFail("Expected malformed configuration to fail")
        }
        XCTAssertTrue(error.localizedDescription.contains("configuration"))
    }

    func testRejectsUnsupportedSchemaVersion() async throws {
        var invalid = MicroConfiguration.default
        invalid.schemaVersion = MicroConfiguration.currentSchemaVersion + 1
        let store = try makeConfigurationStore(containing: invalid)

        let result = await store.load()

        assertInvalidConfigurationResult(result, containing: "schema")
    }

    func testRejectsMissingOrDuplicateLayers() async throws {
        var missing = MicroConfiguration.default
        missing.layers.removeLast()
        var duplicate = MicroConfiguration.default
        duplicate.layers[5] = duplicate.layers[0]

        let missingStore = try makeConfigurationStore(containing: missing)
        let duplicateStore = try makeConfigurationStore(containing: duplicate)
        let missingResult = await missingStore.load()
        let duplicateResult = await duplicateStore.load()
        assertInvalidConfigurationResult(missingResult, containing: "ten")
        assertInvalidConfigurationResult(duplicateResult, containing: "unique")
    }

    func testRejectsUnboundedConfigurationValuesBeforeSaving() async {
        let location = makeTemporaryConfigurationDirectory().appendingPathComponent("config.json")
        let store = ConfigurationStore(fileURL: location)
        var invalid = MicroConfiguration.default
        invalid.layers[0].name = String(repeating: "x", count: 129)

        let result = await store.save(invalid)

        assertInvalidConfigurationResult(result, containing: "name")
        XCTAssertFalse(FileManager.default.fileExists(atPath: location.path))
    }

    func testRejectsInvalidBindingPayloadsBeforeSaving() async {
        let store = ConfigurationStore(
            fileURL: makeTemporaryConfigurationDirectory().appendingPathComponent("config.json")
        )
        var invalid = MicroConfiguration.default
        invalid.assign(
            action: .openApplication(bundleIdentifier: "com..invalid"),
            to: .action6,
            on: .desktop
        )

        let result = await store.save(invalid)

        assertInvalidConfigurationResult(result, containing: "bundle identifier")
    }

    func testOlderGenerationCannotOverwriteNewerGeneration() async throws {
        let location = makeTemporaryConfigurationDirectory().appendingPathComponent("config.json")
        let store = ConfigurationStore(fileURL: location)
        var older = MicroConfiguration.default
        var newer = MicroConfiguration.default
        older.layers[0].name = "Older"
        newer.layers[0].name = "Newer"

        try await store.save(newer, generation: 2).get()
        try await store.save(older, generation: 1).get()

        let loaded = try await store.load().get()
        XCTAssertEqual(loaded.layers[0].name, "Newer")
    }

}
