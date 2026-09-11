import XCTest

@testable import CreatorMicroCore

final class LegacySemanticMigrationTests: XCTestCase {
    func testVersionFiveMovesEveryCustomizedWorkflowToItsSemanticDestination() throws {
        let destinations: [LayerIndex: LayerIndex] = [
            .codex: .codexCLI,
            .agents: .agentFocus,
            .windows: .windowManagement,
            .meetings: .meetingControls,
            .snippets: .snippetCommands,
        ]
        var legacy = versionFiveConfiguration()
        customizeWorkflows(in: &legacy, destinations: destinations)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        assertCustomizedWorkflows(in: migrated, destinations: destinations)
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(migrated))
    }

    func testVersionSixMovesEveryCustomizedWorkflowToItsSemanticDestination() throws {
        let desktop = try XCTUnwrap(MicroConfiguration.default.layer(.desktop))
        let destinations: [LayerIndex: LayerIndex] = [
            .codex: .codexCLI,
            .agents: .claudeCodeCLI,
            .windows: .codexApp,
            .meetings: .claudeApp,
            .snippets: .cursor,
        ]
        var legacy = LegacyVersionSixConfiguration.configuration(desktopChassis: desktop)
        customizeWorkflows(in: &legacy, destinations: destinations)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        assertCustomizedWorkflows(in: migrated, destinations: destinations)
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(migrated))
    }

    func testVersionFiveRemapsLayerTargetsInsideDualPressActions() throws {
        var legacy = versionFiveConfiguration()
        legacy.assign(
            action: .shortOrLongPress(
                shortPress: .layer(.select(.agents)),
                longPress: .layer(.select(.windows))
            ),
            to: .agent0,
            on: .desktop
        )

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(
            migrated.layer(.desktop)?.action(for: .agent0),
            .shortOrLongPress(
                shortPress: .layer(.select(.agentFocus)),
                longPress: .layer(.select(.windowManagement))
            )
        )
    }

    private func customizeWorkflows(
        in configuration: inout MicroConfiguration,
        destinations: [LayerIndex: LayerIndex]
    ) {
        let sources = destinations.keys.sorted { $0.rawValue < $1.rawValue }
        for (offset, source) in sources.enumerated() {
            let marker = "legacy-workflow-\(source.rawValue)"
            let layerIndex = configuration.layers.firstIndex { $0.id == source }
            guard let layerIndex else {
                XCTFail("Missing legacy layer \(source.rawValue)")
                continue
            }
            configuration.layers[layerIndex].name = marker
            configuration.assign(action: .textSnippet(marker), to: .agent0, on: source)
            configuration.applicationLayerRules.append(
                ApplicationLayerRule(
                    bundleIdentifier: "com.example.legacy-\(source.rawValue)",
                    layer: source
                )
            )
            configuration.assign(
                action: .layer(.select(source)),
                to: desktopControls[offset],
                on: .desktop
            )
        }
    }

    private func assertCustomizedWorkflows(
        in configuration: MicroConfiguration,
        destinations: [LayerIndex: LayerIndex]
    ) {
        let sources = destinations.keys.sorted { $0.rawValue < $1.rawValue }
        for (offset, source) in sources.enumerated() {
            guard let destination = destinations[source] else {
                XCTFail("Missing semantic destination for \(source.rawValue)")
                continue
            }
            XCTAssertEqual(
                configuration.layer(destination)?.name,
                "legacy-workflow-\(source.rawValue)"
            )
            XCTAssertEqual(
                configuration.layer(destination)?.action(for: .agent0),
                .textSnippet("legacy-workflow-\(source.rawValue)")
            )
            XCTAssertEqual(configuration.applicationLayerRules[offset].layer, destination)
            XCTAssertEqual(
                configuration.layer(.desktop)?.action(for: desktopControls[offset]),
                .layer(.select(destination))
            )
        }
    }

    private func versionFiveConfiguration() -> MicroConfiguration {
        let ids: [LayerIndex] = [.codex, .desktop, .agents, .windows, .meetings, .snippets]
        return MicroConfiguration(
            schemaVersion: 5,
            microphoneLayout: .separate,
            layers: ids.map(LegacyVersionFiveConfiguration.layer)
        )
    }

    private var desktopControls: [ControlID] {
        [.agent0, .agent1, .agent2, .agent3, .agent4]
    }
}
