import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelKeyAppearanceTests: XCTestCase {
    func testUnassignedControlWithNoSignalIsOff() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.assign(action: .none, to: .action6, on: model.activeLayer)

        XCTAssertNil(model.keyAppearance(for: .action6))
    }

    func testBoundActionUsesItsFunctionCategoryAtIdleBrightnessThenLiftsOnPress() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.assign(action: .copy, to: .action6, on: model.activeLayer)

        let resting = model.keyAppearance(for: .action6)
        XCTAssertEqual(resting?.color, SemanticLightingPalette.textClipboard)
        XCTAssertEqual(resting?.brightness, SemanticLightingPalette.idleBrightness)

        model.pressedControls.insert(.action6)
        XCTAssertEqual(model.keyAppearance(for: .action6)?.brightness, SemanticLightingPalette.pressBrightness)
    }

    func testMissingAgentDoesNotBlackOutAnAssignedFunctionKeyOnAgentFocusLayer() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.assign(action: .openTerminal, to: .agent0, on: .agentFocus)
        model.select(layer: .agentFocus, source: .editor)

        let appearance = model.keyAppearance(for: .agent0)

        XCTAssertEqual(appearance?.color, SemanticLightingPalette.appWindowLaunch)
        XCTAssertNotEqual(appearance?.color, .black)
    }

    func testAgentStatusOnlyAppliesOnTheAgentFocusLayer() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.assign(action: .agentFocus(sessionID: "slot-1"), to: .agent0, on: .agentFocus)
        model.configuration.assign(action: .copy, to: .agent0, on: .desktop)
        model.agentSnapshot = AgentSlotSnapshot(
            slots: [
                AgentSlot(
                    id: .one,
                    session: AgentSession(
                        id: AgentSessionID(source: .localProcess, externalID: "1"),
                        title: "Agent",
                        detail: nil,
                        status: .working,
                        updatedAt: Date(),
                        focusTarget: nil
                    )
                )
            ],
            adapterAvailability: [:]
        )

        model.select(layer: .agentFocus, source: .editor)
        XCTAssertEqual(model.keyAppearance(for: .agent0)?.color, RGBColor(red: 48, green: 79, blue: 254))

        model.select(layer: .desktop, source: .editor)
        XCTAssertEqual(model.keyAppearance(for: .agent0)?.color, SemanticLightingPalette.textClipboard)
    }

    func testObservedAudioSignalOutranksTheRestingFunctionCategoryColor() {
        let model = AppModel(configurationStore: temporaryStore())
        model.configuration.assign(action: .inputMute(.toggle), to: .action6, on: model.activeLayer)
        model.audioSnapshot = SystemAudioSnapshot(
            inputMute: .muted,
            outputMute: .unavailable,
            outputVolume: nil
        )

        XCTAssertEqual(model.keyAppearance(for: .action6)?.color, SemanticLightingPalette.audioMuted)
    }

    private func temporaryStore() -> ConfigurationStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return ConfigurationStore(fileURL: url)
    }
}
