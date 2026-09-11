import XCTest

@testable import CreatorMicroCore

final class MicroRuntimeRouterTests: XCTestCase {
    func testRegularButtonRoutesConfiguredPressAndRelease() {
        let layer = LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [.action6: .openTerminal]
        )
        var router = MicroRuntimeRouter(microphoneLayout: .separate)

        let press = router.route(input(.action6, .pressed), on: layer)
        let release = router.route(input(.action6, .released), on: layer)

        XCTAssertEqual(press, [.init(action: .openTerminal, phase: .pressed)])
        XCTAssertEqual(release, [.init(action: .openTerminal, phase: .released)])
    }

    func testRegularReleaseUsesTheActionCapturedAtPressTime() {
        let pressedLayer = LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [.action6: .dictation(.init(providerID: .rede, behavior: .holdToTalk))]
        )
        let changedLayer = LayerConfiguration(
            id: .agents,
            name: "Agents",
            bindings: [.action6: .openTerminal]
        )
        var router = MicroRuntimeRouter(microphoneLayout: .separate)

        let press = router.route(input(.action6, .pressed), on: pressedLayer)
        let release = router.route(input(.action6, .released), on: changedLayer)

        XCTAssertEqual(release, press.map { .init(action: $0.action, phase: .released) })
    }

    func testRegularDuplicateReportsAndResetPreserveBalancedPhases() {
        let layer = LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [.action6: .openTerminal]
        )
        var router = MicroRuntimeRouter(microphoneLayout: .separate)

        let press = router.route(input(.action6, .pressed), on: layer)
        let duplicate = router.route(input(.action6, .pressed), on: layer)
        let reset = router.reset()

        XCTAssertEqual(press, [.init(action: .openTerminal, phase: .pressed)])
        XCTAssertTrue(duplicate.isEmpty)
        XCTAssertEqual(reset, [.init(action: .openTerminal, phase: .released)])
    }

    func testEncoderPulseRoutesAsSinglePress() {
        let layer = LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [.encoderClockwise: .volume(.increase)]
        )
        var router = MicroRuntimeRouter(microphoneLayout: .separate)

        let events = router.route(input(.encoderClockwise, .pulse), on: layer)

        XCTAssertEqual(events, [.init(action: .volume(.increase), phase: .pressed)])
    }

    func testMicrophoneSwitchesUseLinkedDeduplication() {
        let dictation = CreatorAction.dictation(
            .init(providerID: .rede, behavior: .holdToTalk)
        )
        let layer = LayerConfiguration(
            id: .desktop,
            name: "Desktop",
            bindings: [.action10: dictation, .action11: .approval]
        )
        var router = MicroRuntimeRouter(microphoneLayout: .linked)

        let first = router.route(input(.action10, .pressed), on: layer)
        let duplicate = router.route(input(.action11, .pressed), on: layer)

        XCTAssertEqual(first, [.init(action: dictation, phase: .pressed)])
        XCTAssertTrue(duplicate.isEmpty)
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
