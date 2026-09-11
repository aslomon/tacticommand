import XCTest

@testable import CreatorMicroCore

extension WorkflowPresetMigrationTests {
    func testVersionSixMigratesTheExactTranscriptionErrorBaseline() throws {
        let desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        let legacy = LegacyVersionSixConfiguration.configuration(desktopChassis: desktop)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(migrated.layers.map(\.id), LayerIndex.all)
        XCTAssertEqual(migrated.layers.map(\.name), MicroConfiguration.default.layers.map(\.name))
    }

    func testVersionSixPreservesCustomizedLayerAndDesktopChassis() throws {
        var desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        desktop.assign(.pastePlainText, to: .action6)
        desktop.assign(.openFinder, to: .action8)
        desktop.assign(.openTerminal, to: .encoderClockwise)
        desktop.joystick = LayerJoystickConfiguration(
            mode: .pointer,
            deadZone: 0.23,
            maximumSpeed: 910
        )
        var legacy = LegacyVersionSixConfiguration.configuration(desktopChassis: desktop)
        legacy.layers[2].name = "My Cloud Workflow"
        legacy.assign(action: .openFinder, to: .agent0, on: .agents)
        legacy.microphoneLayout = .linked
        legacy.launchAtLogin = true

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.layer(.desktop), desktop)
        XCTAssertEqual(migrated.layer(.agents)?.name, "My Cloud Workflow")
        XCTAssertEqual(migrated.layer(.agents)?.action(for: .agent0), .openFinder)
        XCTAssertEqual(migrated.layer(.windows)?.name, "Claude App")
        XCTAssertEqual(migrated.layer(.cursor)?.name, "Cursor")
        XCTAssertEqual(migrated.layer(.meetingControls)?.name, "Meetings")
        XCTAssertEqual(migrated.layer(.windowManagement)?.name, "Window Management")
        XCTAssertEqual(migrated.layer(.snippetCommands)?.name, "Snippets")
        XCTAssertEqual(migrated.layers.map(\.id), LayerIndex.all)
        XCTAssertEqual(migrated.microphoneLayout, .linked)
        XCTAssertTrue(migrated.launchAtLogin)
        for id in LayerIndex.all where id != .desktop && id != .agents {
            XCTAssertEqual(migrated.layer(id)?.action(for: .action6), .pastePlainText)
            XCTAssertEqual(migrated.layer(id)?.action(for: .action8), .openFinder)
            XCTAssertEqual(migrated.layer(id)?.action(for: .encoderClockwise), .openTerminal)
            XCTAssertEqual(migrated.layer(id)?.joystick, desktop.joystick)
        }
    }

    func testVersionSixRemapsEveryKnownApplicationRuleWithoutCollisions() throws {
        let desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        var legacy = LegacyVersionSixConfiguration.configuration(desktopChassis: desktop)
        let sources: [LayerIndex] = [.codex, .agents, .windows, .meetings, .snippets]
        legacy.applicationLayerRules = sources.enumerated().map { index, layer in
            ApplicationLayerRule(bundleIdentifier: "com.example.legacy\(index)", layer: layer)
        }

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(
            migrated.applicationLayerRules.map(\.layer),
            [.codexCLI, .claudeCodeCLI, .codexApp, .claudeApp, .cursor]
        )
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(migrated))
    }
}
