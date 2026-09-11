import XCTest

@testable import CreatorMicroCore

extension WorkflowPresetMigrationTests {
    func testVersionFiveMigratesUntouchedLegacyWorkflowsAndPreservesDesktop() throws {
        var desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        desktop.assign(.pastePlainText, to: .action6)
        desktop.assign(.openFinder, to: .action8)
        desktop.assign(.openTerminal, to: .encoderClockwise)
        desktop.joystick = LayerJoystickConfiguration(
            mode: .pointer,
            deadZone: 0.164_655_671_296_296_3,
            maximumSpeed: 1_550
        )
        let legacy = WorkflowPresetMigrationFixtures.versionFiveConfiguration(desktop: desktop)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(migrated.layer(.desktop), desktop)
        XCTAssertEqual(
            migrated.layers.map(\.name),
            [
                "Desktop",
                "Claude Code CLI",
                "Claude App",
                "Codex CLI",
                "Codex App",
                "Cursor",
                "Meetings",
                "Agent Focus",
                "Window Management",
                "Snippets",
            ]
        )
        for id in LayerIndex.all where id != .desktop {
            XCTAssertEqual(migrated.layer(id)?.action(for: .action6), .pastePlainText)
            XCTAssertEqual(migrated.layer(id)?.action(for: .action8), .openFinder)
            XCTAssertEqual(migrated.layer(id)?.action(for: .encoderClockwise), .openTerminal)
            XCTAssertEqual(migrated.layer(id)?.joystick, desktop.joystick)
        }
    }

    func testVersionFivePreservesCustomizedLegacyWorkflowLayer() throws {
        var legacy = WorkflowPresetMigrationFixtures.versionFiveConfiguration(
            desktop: WorkflowPresetMigrationFixtures.legacyDesktopLayer
        )
        legacy.layers[2].name = "My Agents"
        legacy.assign(action: .openFinder, to: .agent0, on: .agents)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.layer(.agentFocus)?.name, "My Agents")
        XCTAssertEqual(migrated.layer(.agentFocus)?.action(for: .agent0), .openFinder)
        XCTAssertEqual(migrated.layer(.claudeCodeCLI)?.name, "Claude Code CLI")
        XCTAssertEqual(migrated.layer(.windows)?.name, "Claude App")
        XCTAssertEqual(migrated.layers.map(\.id), LayerIndex.all)
    }

    func testVersionFiveMovesCustomizedMeetingsIntoTheNewMeetingsSlot() throws {
        var legacy = WorkflowPresetMigrationFixtures.versionFiveConfiguration(
            desktop: WorkflowPresetMigrationFixtures.legacyDesktopLayer
        )
        legacy.assign(action: .none, to: .action8, on: .meetings)
        legacy.assign(action: .none, to: .encoderPress, on: .meetings)
        legacy.applicationLayerRules = [
            ApplicationLayerRule(bundleIdentifier: "com.example.meeting", layer: .meetings)
        ]
        let customizedMeetings = try XCTUnwrap(legacy.layer(.meetings))

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.layer(.codexCLI)?.name, "Codex CLI")
        XCTAssertEqual(migrated.layer(.meetingControls)?.name, customizedMeetings.name)
        XCTAssertEqual(migrated.layer(.meetingControls)?.bindings, customizedMeetings.bindings)
        XCTAssertEqual(migrated.layer(.meetingControls)?.joystick, customizedMeetings.joystick)
        XCTAssertEqual(migrated.applicationLayerRules.first?.layer, .meetingControls)
    }

    func testVersionFiveMigrationKeepsApplicationRulesAndGlobalPreferences() throws {
        var legacy = WorkflowPresetMigrationFixtures.versionFiveConfiguration(
            desktop: WorkflowPresetMigrationFixtures.legacyDesktopLayer
        )
        legacy.applicationLayerRules = [
            ApplicationLayerRule(bundleIdentifier: "com.apple.Terminal", layer: .codex)
        ]
        legacy.joystick = JoystickConfiguration(deadZone: 0.28, maximumSpeed: 720)
        legacy.launchAtLogin = true

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.applicationLayerRules.first?.layer, .codexCLI)
        XCTAssertEqual(
            migrated.applicationLayerRules.first?.bundleIdentifier,
            legacy.applicationLayerRules.first?.bundleIdentifier
        )
        XCTAssertEqual(migrated.joystick, legacy.joystick)
        XCTAssertTrue(migrated.launchAtLogin)
    }

    func testVersionFiveRemapsEveryKnownApplicationRuleByWorkflowMeaning() throws {
        var legacy = WorkflowPresetMigrationFixtures.versionFiveConfiguration(
            desktop: WorkflowPresetMigrationFixtures.legacyDesktopLayer
        )
        let sources: [LayerIndex] = [.codex, .agents, .windows, .meetings, .snippets]
        legacy.applicationLayerRules = sources.enumerated().map { index, layer in
            ApplicationLayerRule(bundleIdentifier: "com.example.workflow\(index)", layer: layer)
        }

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(
            migrated.applicationLayerRules.map(\.layer),
            [.codexCLI, .agentFocus, .windowManagement, .meetingControls, .snippetCommands]
        )
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(migrated))
    }
}
