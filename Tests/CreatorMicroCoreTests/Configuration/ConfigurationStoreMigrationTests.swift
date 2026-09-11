import XCTest

@testable import CreatorMicroCore

extension ConfigurationStoreTests {
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
        XCTAssertEqual(
            migrated.layer(.windowManagement)?.action(for: .agent1),
            .pointer(.click(.primary))
        )
        XCTAssertEqual(
            migrated.layer(.windowManagement)?.action(for: .agent4),
            .switchApplication(.previous)
        )
        XCTAssertEqual(
            migrated.layer(.windowManagement)?.action(for: .agent5),
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
        let codexIndex = try XCTUnwrap(
            legacy.layers.firstIndex(where: { $0.id == .codex })
        )
        legacy.layers[codexIndex] = LayerConfiguration(
            id: .codex,
            name: "Codex",
            bindings: [.action9: .layer(.next)]
        )
        legacy.assign(action: .returnKey, to: .action8, on: .meetings)
        legacy.assign(action: .openFinder, to: .encoderPress, on: .meetings)
        legacy.assign(action: .none, to: .encoderClockwise, on: .windows)
        let store = try makeConfigurationStore(containing: legacy)

        let migrated = try await store.load().get()

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(
            migrated.layer(.codex)?.action(for: .action8),
            .slashCommand(command: "/", submit: false)
        )
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .encoderClockwise), .volume(.increase))
        XCTAssertEqual(
            migrated.layer(.codex)?.action(for: .encoderCounterClockwise),
            .volume(.decrease)
        )
        XCTAssertEqual(migrated.layer(.codex)?.action(for: .encoderPress), .outputMute(.toggle))
        XCTAssertEqual(migrated.layer(.meetingControls)?.action(for: .action8), .returnKey)
        XCTAssertEqual(migrated.layer(.meetingControls)?.action(for: .encoderPress), .openFinder)
        XCTAssertEqual(
            migrated.layer(.windowManagement)?.action(for: .encoderClockwise),
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

        XCTAssertEqual(migrated.layer(.codexCLI)?.action(for: .action8), CreatorAction.none)
        XCTAssertEqual(
            migrated.layer(.codexCLI)?.action(for: .encoderClockwise),
            CreatorAction.none
        )
        XCTAssertEqual(
            migrated.layer(.codexCLI)?.action(for: .encoderCounterClockwise),
            CreatorAction.none
        )
        XCTAssertEqual(migrated.layer(.codexCLI)?.action(for: .encoderPress), CreatorAction.none)
        XCTAssertEqual(migrated.layer(.codexCLI)?.action(for: .action6), .openTerminal)
    }
}
