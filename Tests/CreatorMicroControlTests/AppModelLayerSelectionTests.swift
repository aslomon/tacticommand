import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelLayerSelectionTests: XCTestCase {
    func testPhysicalLayerActionChangesTheLocalLayerAndRecordsItsSource() async throws {
        let model = AppModel(configurationStore: temporaryStore())

        try await model.executeRoutedAction(
            .init(action: .layer(.next), phase: .pressed)
        ).get()

        XCTAssertEqual(model.activeLayer, .agents)
        XCTAssertEqual(model.layerSelection.source, .physicalKey)
    }

    func testLayerActionIgnoresRelease() async throws {
        let model = AppModel(configurationStore: temporaryStore())

        try await model.executeRoutedAction(
            .init(action: .layer(.next), phase: .released)
        ).get()

        XCTAssertEqual(model.activeLayer, .desktop)
    }

    func testActualLayerChangePresentsActiveAndNextLayerNames() {
        let presenter = RecordingLayerChangePresenter()
        let model = AppModel(configurationStore: temporaryStore())
        model.layerChangePresenter = presenter

        model.select(layer: .agents, source: .physicalKey)

        XCTAssertEqual(
            presenter.presentations,
            [
                LayerChangeHUDPresentation(
                    activeLayerName: "Agents",
                    nextLayerName: "Windows",
                    source: .physicalKey
                )
            ]
        )
    }

    func testReselectingActiveLayerDoesNotPresentDuplicateFeedback() {
        let presenter = RecordingLayerChangePresenter()
        let model = AppModel(configurationStore: temporaryStore())
        model.layerChangePresenter = presenter

        model.select(layer: .desktop, source: .editor)

        XCTAssertTrue(presenter.presentations.isEmpty)
    }

    func testDeviceLayerIndexDoesNotOverrideAutomationLayerSelection() async throws {
        let model = AppModel(configurationStore: temporaryStore())
        await model.loadConfiguration()

        try await model.makeAutomationHandlers().setLayerIfReady(.windows).get()
        XCTAssertEqual(model.layerSelection.source, .automation)

        await model.handle(.status(DeviceStatus(layerIndex: 4)))
        XCTAssertEqual(model.activeLayer, .windows)
        XCTAssertEqual(model.layerSelection.source, .automation)
        XCTAssertEqual(model.layerSelection.firmwareLayerIndex, 4)
        XCTAssertEqual(model.deviceStatus?.layerIndex, 4)
    }

    func testApplicationRuleOnlyOverridesWhileItsApplicationIsFrontmost() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.applicationLayerRules = [
            ApplicationLayerRule(
                bundleIdentifier: "com.openai.codex",
                layer: .codex
            )
        ]
        model.select(layer: .windows, source: .physicalKey)

        model.applyFrontmostApplication("com.openai.codex")

        XCTAssertEqual(model.activeLayer, .codex)
        XCTAssertEqual(model.layerSelection.source, .applicationRule)

        model.applyFrontmostApplication("com.apple.finder")

        XCTAssertEqual(model.activeLayer, .windows)
        XCTAssertEqual(model.layerSelection.source, .physicalKey)
    }

    func testUnknownFrontmostApplicationDoesNotChangeManualLayer() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.applicationLayerRules = [
            ApplicationLayerRule(
                bundleIdentifier: "com.openai.codex",
                layer: .codex
            )
        ]
        model.select(layer: .meetings, source: .editor)

        model.applyFrontmostApplication("com.apple.finder")

        XCTAssertEqual(model.activeLayer, .meetings)
        XCTAssertEqual(model.layerSelection.source, .editor)
    }

    func testManualLayerSelectionWinsWhileMatchedApplicationRemainsFrontmost() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.applicationLayerRules = [
            ApplicationLayerRule(
                bundleIdentifier: "com.openai.codex",
                layer: .codex
            )
        ]
        model.select(layer: .windows, source: .physicalKey)
        model.applyFrontmostApplication("com.openai.codex")

        model.select(layer: .desktop, source: .editor)
        model.applyFrontmostApplication("com.openai.codex")

        XCTAssertEqual(model.activeLayer, .desktop)
        XCTAssertEqual(model.layerSelection.source, .editor)

        model.applyFrontmostApplication("com.apple.finder")
        model.applyFrontmostApplication("com.openai.codex")

        XCTAssertEqual(model.activeLayer, .codex)
        XCTAssertEqual(model.layerSelection.source, .applicationRule)
    }

    private func temporaryStore() -> ConfigurationStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return ConfigurationStore(fileURL: url)
    }
}

@MainActor
private final class RecordingLayerChangePresenter: LayerChangeHUDPresenting {
    private(set) var presentations: [LayerChangeHUDPresentation] = []

    func show(_ presentation: LayerChangeHUDPresentation) {
        presentations.append(presentation)
    }
}
