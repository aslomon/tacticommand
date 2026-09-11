import XCTest

@testable import CreatorMicroCore

extension WorkflowPresetMigrationTests {
    func testVersionSevenAddsShortcutNamesToUntouchedPresetLayers() throws {
        let legacy = WorkflowPresetMigrationFixtures.versionSevenConfigurationWithoutShortcutNames()

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(migrated.layers, MicroConfiguration.default.layers)
        XCTAssertEqual(
            migrated.layer(.claudeCodeCLI)?.action(for: .agent1),
            .keyboardShortcut(
                KeyShortcut(key: "tab", modifiers: [.shift], displayName: "Permission Mode")
            )
        )
    }

    func testVersionSevenPreservesCustomizedShortcutWhileNamingUntouchedPresets() throws {
        var legacy = WorkflowPresetMigrationFixtures.versionSevenConfigurationWithoutShortcutNames()
        let custom = KeyShortcut(key: "g", modifiers: [.command], displayName: "My Command")
        legacy.assign(action: .keyboardShortcut(custom), to: .agent1, on: .claudeCodeCLI)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(
            migrated.layer(.claudeCodeCLI)?.action(for: .agent1),
            .keyboardShortcut(custom)
        )
        XCTAssertEqual(
            migrated.layer(.cursor)?.action(for: .agent0),
            .keyboardShortcut(KeyShortcut(key: "i", modifiers: [.command], displayName: "Agent"))
        )
    }
}
