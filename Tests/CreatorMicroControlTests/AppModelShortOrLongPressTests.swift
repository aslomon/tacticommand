import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelShortOrLongPressTests: XCTestCase {
    func testShortPhysicalPressSchedulesThenEmitsACompleteTapOnRelease() async {
        let model = makeModel()
        let action = dualAction

        let pressed = model.resolvePressActions(
            [.init(action: action, phase: .pressed)],
            from: input(.action6, .pressed)
        )
        let released = model.resolvePressActions(
            [.init(action: action, phase: .released)],
            from: input(.action6, .released)
        )

        XCTAssertTrue(pressed.isEmpty)
        XCTAssertEqual(
            released,
            [
                .init(action: .openFinder, phase: .pressed),
                .init(action: .openFinder, phase: .released),
            ]
        )
        XCTAssertFalse(model.shortOrLongPressState.isTracking(.action6))
        await model.shutdown()
    }

    func testLayerChangeAndDisconnectResetTrackedLongPresses() async throws {
        let model = makeModel()

        try activateLongPress(in: model, control: .action6)
        model.select(layer: .agents)
        XCTAssertFalse(model.shortOrLongPressState.isTracking(.action6))

        try activateLongPress(in: model, control: .action7)
        await model.consume(.connection(.disconnected))
        XCTAssertFalse(model.shortOrLongPressState.isTracking(.action7))
        await model.shutdown()
    }

    func testMicrophoneLayoutChangeDropsPendingDualPress() async throws {
        let model = makeModel()
        _ = try beginPress(in: model, control: .action10)

        model.setMicrophoneLayout(.linked)

        XCTAssertFalse(model.shortOrLongPressState.isTracking(.action10))
        await model.shutdown()
    }

    func testRuntimeResetReleasesOnlyTheActiveLongPressChild() async throws {
        let model = makeModel()
        let action = dualAction
        model.configuration.assign(action: action, to: .action10, on: .desktop)
        _ = model.runtimeRouter.route(
            input(.action10, .pressed),
            on: model.selectedLayer
        )
        try activateLongPress(in: model, control: .action10)

        XCTAssertEqual(
            model.resetActiveRoutedActions(),
            [.init(action: .returnKey, phase: .released)]
        )
        await model.shutdown()
    }

    func testPulseInputNeverStartsDualPressTimer() async {
        let model = makeModel()

        let actions = model.resolvePressActions(
            [.init(action: dualAction, phase: .pressed)],
            from: input(.encoderClockwise, .pulse)
        )

        XCTAssertTrue(actions.isEmpty)
        XCTAssertFalse(model.shortOrLongPressState.isTracking(.encoderClockwise))
        XCTAssertEqual(
            model.lastError,
            "Encoder rotations cannot use short and long press actions."
        )
        await model.shutdown()
    }

    private var dualAction: CreatorAction {
        .shortOrLongPress(
            shortPress: .openFinder,
            longPress: .openTerminal
        )
    }

    private func makeModel() -> AppModel {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
        return AppModel(configurationStore: ConfigurationStore(fileURL: url))
    }

    private func activateLongPress(
        in model: AppModel,
        control: ControlID
    ) throws {
        let deadline = try beginPress(in: model, control: control)
        _ = model.shortOrLongPressState.thresholdReached(deadline)
    }

    private func beginPress(
        in model: AppModel,
        control: ControlID
    ) throws -> ShortOrLongPressDeadline {
        let effects = model.shortOrLongPressState.begin(
            control: control,
            shortPress: .openFinder,
            longPress: .returnKey
        )
        guard let firstEffect = effects.first,
            case .schedule(let deadline) = firstEffect
        else {
            throw AppModelPressTestFailure.missingDeadline
        }
        return deadline
    }

    private func input(
        _ control: ControlID,
        _ phase: MicroInputPhase
    ) -> MicroInputEvent {
        MicroInputEvent(
            control: control,
            phase: phase,
            rawActivity: phase == .released ? 0 : 1,
            agentIndex: control.agentIndex
        )
    }
}

private enum AppModelPressTestFailure: Error {
    case missingDeadline
}
