import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelLightingFeedbackTests: XCTestCase {
    func testCreatorWideCapRoutesOnceAndOnlyReleasesAfterBothPositions() {
        let model = makeModel()
        model.deviceIdentity = DeviceIdentitySnapshot(transport: .usb, productIdentifier: 0x8298)
        model.configuration.microphoneLayout = .separate
        model.configuration.assign(action: .copy, to: .action10, on: model.activeLayer)
        model.configuration.assign(action: .openTerminal, to: .action11, on: model.activeLayer)
        model.configureRuntimeRouter()
        let press = model.runtimeRouter.route(input(.action10, .pressed), on: model.selectedLayer)
        XCTAssertEqual(press, [.init(action: .copy, phase: .pressed)])
        XCTAssertTrue(model.runtimeRouter.route(input(.action11, .pressed), on: model.selectedLayer).isEmpty)
        XCTAssertTrue(model.runtimeRouter.route(input(.action10, .released), on: model.selectedLayer).isEmpty)
        XCTAssertEqual(
            model.runtimeRouter.route(input(.action11, .released), on: model.selectedLayer),
            [.init(action: .copy, phase: .released)])
        XCTAssertEqual(model.configuration.microphoneLayout, .separate)
        XCTAssertEqual(model.selectedLayer.action(for: .action11), .openTerminal)
        XCTAssertEqual(model.keyAppearance(for: .action10), model.keyAppearance(for: .action11))
    }

    func testCodexKeepsSeparateSavedActions() {
        let model = makeModel()
        model.deviceIdentity = DeviceIdentitySnapshot(transport: .usb, productIdentifier: 0x8360)
        model.configuration.assign(action: .copy, to: .action10, on: model.activeLayer)
        model.configuration.assign(action: .openTerminal, to: .action11, on: model.activeLayer)
        model.configureRuntimeRouter()
        XCTAssertEqual(
            model.runtimeRouter.route(input(.action11, .pressed), on: model.selectedLayer),
            [.init(action: .openTerminal, phase: .pressed)])
        XCTAssertNotEqual(model.keyAppearance(for: .action10), model.keyAppearance(for: .action11))
    }

    func testFailureWinsOverPressAndStaleFailureCannotAffectAnotherLayer() async {
        let model = makeModel()
        model.configuration.assign(action: .copy, to: .action6, on: model.activeLayer)
        let generation = model.lightingGeneration
        model.recordLightingFailure(control: .action6, generation: generation)
        model.pressedControls.insert(.action6)
        XCTAssertEqual(model.keyAppearance(for: .action6)?.color, SemanticLightingPalette.audioMuted)
        model.select(layer: .agentFocus)
        model.configuration.assign(action: .copy, to: .action6, on: model.activeLayer)
        model.recordLightingFailure(control: .action6, generation: generation)
        XCTAssertEqual(model.keyAppearance(for: .action6)?.color, SemanticLightingPalette.textClipboard)
        await model.shutdown()
    }

    func testActualActionFailureIsAttributedToItsInputControl() async {
        let model = makeModel()
        model.configuration.assign(action: .copy, to: .action6, on: model.activeLayer)
        await model.execute(.init(action: .agentFocus(sessionID: "missing"), phase: .pressed), control: .action6)
        XCTAssertNotNil(model.lastError)
        XCTAssertEqual(model.keyAppearance(for: .action6)?.color, SemanticLightingPalette.audioMuted)
        XCTAssertNotEqual(model.keyAppearance(for: .action7)?.color, SemanticLightingPalette.audioMuted)
        await model.shutdown()
    }

    private func makeModel() -> AppModel {
        AppModel(
            configurationStore: ConfigurationStore(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString).appendingPathComponent("configuration.json")))
    }
    private func input(_ control: ControlID, _ phase: MicroInputPhase) -> MicroInputEvent {
        MicroInputEvent(control: control, phase: phase, rawActivity: phase == .released ? 0 : 1, agentIndex: nil)
    }
}
