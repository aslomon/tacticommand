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
        assertInvalidConfigurationResult(missingResult, containing: "six")
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

    func testVersionOneDefaultsMigrateToAdjacentPrimaryClickWithoutResettingUserBindings() async throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 1
        legacy.assign(action: .none, to: .action9, on: .codex)
        legacy.assign(action: .pointer(.click(.primary)), to: .agent0, on: .desktop)
        legacy.assign(action: .pointer(.click(.secondary)), to: .agent1, on: .desktop)
        legacy.assign(action: .pointer(.click(.middle)), to: .agent2, on: .desktop)
        legacy.assign(action: .switchApplication(.next), to: .action9, on: .desktop)
        legacy.assign(action: .switchApplication(.next), to: .action9, on: .agents)
        legacy.assign(action: .switchApplication(.next), to: .action9, on: .windows)
        legacy.assign(action: .none, to: .action9, on: .meetings)
        legacy.assign(action: .switchApplication(.next), to: .action9, on: .snippets)
        legacy.assign(action: .switchApplication(.previous), to: .agent1, on: .windows)
        legacy.assign(action: .pointer(.click(.primary)), to: .agent4, on: .windows)
        legacy.assign(action: .pointer(.click(.secondary)), to: .agent5, on: .windows)
        legacy.assign(action: .openTerminal, to: .agent2, on: .desktop)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(
            migrated.layer(.desktop)?.action(for: .agent0),
            CreatorAction.none
        )
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent2), .openTerminal)
        XCTAssertEqual(migrated.layer(.windows)?.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(migrated.layer(.windows)?.action(for: .agent4), .switchApplication(.previous))
        XCTAssertEqual(
            migrated.layer(.windows)?.action(for: .agent5),
            CreatorAction.none
        )
        for layer in migrated.layers {
            XCTAssertEqual(layer.action(for: .action9), .layer(.next))
        }
    }

    func testVersionOneMigrationPreservesCustomizedClickPositions() async throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 1
        legacy.assign(action: .openFinder, to: .agent0, on: .desktop)
        legacy.assign(action: .returnKey, to: .agent1, on: .desktop)
        legacy.assign(action: .openTerminal, to: .action9, on: .desktop)
        legacy.assign(action: .escapeKey, to: .agent5, on: .windows)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent0), .openFinder)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent1), .returnKey)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .action9), .openTerminal)
        XCTAssertEqual(migrated.layer(.windows)?.action(for: .agent5), .escapeKey)
    }

    func testVersionTwoMigratesDesktopGeometryWithoutChangingJoystickOrOtherBindings() async throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 2
        legacy.assign(
            action: .shortOrLongPress(
                shortPress: .pointer(.click(.primary)),
                longPress: .pointer(.click(.secondary))
            ),
            to: .agent1,
            on: .desktop
        )
        legacy.assign(action: .none, to: .agent2, on: .desktop)
        legacy.assign(action: .escapeKey, to: .agent5, on: .desktop)
        legacy.assign(action: .openFinder, to: .agent0, on: .desktop)
        let joystick = LayerJoystickConfiguration(
            mode: .pointer,
            deadZone: 0.02,
            maximumSpeed: 1_550
        )
        legacy.setJoystick(joystick, on: .desktop)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent2), .escapeKey)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent5), .deleteKey)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent0), .openFinder)
        XCTAssertEqual(
            migrated.layer(.desktop)?.joystick,
            LayerJoystickConfiguration(
                mode: .arrowKeys,
                deadZone: joystick.deadZone,
                maximumSpeed: joystick.maximumSpeed
            )
        )
    }

    func testVersionTwoMigrationPreservesCustomizedDesktopGeometryKeys() async throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 2
        legacy.assign(action: .returnKey, to: .agent1, on: .desktop)
        legacy.assign(action: .openTerminal, to: .agent2, on: .desktop)
        legacy.assign(action: .openFinder, to: .agent5, on: .desktop)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent1), .returnKey)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent2), .openTerminal)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent5), .openFinder)
    }

    func testVersionFourUpdatesExactLegacyCodexDefaultWithoutChangingCustomLayers() async throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 4
        legacy.assign(action: .none, to: .action8, on: .codex)
        legacy.assign(action: .none, to: .encoderClockwise, on: .codex)
        legacy.assign(action: .none, to: .encoderCounterClockwise, on: .codex)
        legacy.assign(action: .none, to: .encoderPress, on: .codex)
        legacy.assign(action: .returnKey, to: .action8, on: .meetings)
        legacy.assign(action: .openFinder, to: .encoderPress, on: .meetings)
        legacy.assign(action: .none, to: .encoderClockwise, on: .windows)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .action8), .inputMute(.toggle))
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .encoderClockwise), .volume(.increase))
        XCTAssertEqual(
            migrated.layer(.codex)?.action(for: .encoderCounterClockwise),
            .volume(.decrease)
        )
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .encoderPress), .outputMute(.toggle))
        XCTAssertEqual(migrated.layer(.meetings)?.action(for: .action8), .returnKey)
        XCTAssertEqual(migrated.layer(.meetings)?.action(for: .encoderPress), .openFinder)
        XCTAssertEqual(
            migrated.layer(.windows)?.action(for: .encoderClockwise),
            CreatorAction.none
        )
    }

    func testVersionFourDoesNotInferMissingAudioBindingsInCustomizedCodexLayer() async throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 4
        legacy.assign(action: .none, to: .action8, on: .codex)
        legacy.assign(action: .none, to: .encoderClockwise, on: .codex)
        legacy.assign(action: .none, to: .encoderCounterClockwise, on: .codex)
        legacy.assign(action: .none, to: .encoderPress, on: .codex)
        legacy.assign(action: .openTerminal, to: .action6, on: .codex)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.layer(.codex)?.action(for: .action8), CreatorAction.none)
        XCTAssertEqual(
            migrated.layer(.codex)?.action(for: .encoderClockwise),
            CreatorAction.none
        )
        XCTAssertEqual(
            migrated.layer(.codex)?.action(for: .encoderCounterClockwise),
            CreatorAction.none
        )
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .encoderPress), CreatorAction.none)
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .action6), .openTerminal)
    }

}
