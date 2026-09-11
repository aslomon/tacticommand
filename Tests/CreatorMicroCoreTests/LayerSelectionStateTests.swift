import XCTest

@testable import CreatorMicroCore

final class LayerSelectionStateTests: XCTestCase {
    func testLayerCommandsFollowTheTenLayerSoftwareCycle() {
        XCTAssertEqual(
            LayerIndex.all,
            [
                .desktop,
                .claudeCodeCLI,
                .claudeApp,
                .codexCLI,
                .codexApp,
                .cursor,
                .meetingControls,
                .agentFocus,
                .windowManagement,
                .snippetCommands,
            ]
        )
        XCTAssertEqual(LayerCommand.next.destination(from: .desktop), .claudeCodeCLI)
        XCTAssertEqual(LayerCommand.next.destination(from: .snippetCommands), .desktop)
        XCTAssertEqual(LayerCommand.previous.destination(from: .desktop), .snippetCommands)
        XCTAssertEqual(LayerCommand.previous.destination(from: .cursor), .codexApp)
        XCTAssertEqual(LayerCommand.select(.meetings).destination(from: .desktop), .meetings)
    }

    func testDisplayPositionUsesCycleOrderInsteadOfSerializedRawValue() {
        XCTAssertEqual(LayerIndex.desktop.displayPosition, 1)
        XCTAssertEqual(LayerIndex.claudeCodeCLI.displayPosition, 2)
        XCTAssertEqual(LayerIndex.meetingControls.displayPosition, 7)
        XCTAssertEqual(LayerIndex.agentFocus.displayPosition, 8)
        XCTAssertEqual(LayerIndex.windowManagement.displayPosition, 9)
        XCTAssertEqual(LayerIndex.snippetCommands.displayPosition, 10)
    }

    func testLocalSelectionRecordsItsExactSourceWithoutFirmwareConfirmation() {
        var state = LayerSelectionState(active: .desktop)

        state.select(.agents, source: .physicalKey)

        XCTAssertEqual(state.active, .agents)
        XCTAssertEqual(state.source, .physicalKey)
        XCTAssertNil(state.firmwareLayerIndex)
    }

    func testDeviceStatusIsObservedWithoutChangingTheSoftwareSelection() {
        var state = LayerSelectionState(active: .agents, source: .automation)

        XCTAssertTrue(state.observe(status: DeviceStatus(layerIndex: 4)))

        XCTAssertEqual(state.active, .agents)
        XCTAssertEqual(state.source, .automation)
        XCTAssertEqual(state.firmwareLayerIndex, 4)
    }

    func testFirmwareObservationKeepsUnknownRawValuesSeparateFromAppLayers() {
        var state = LayerSelectionState(active: .agents)

        XCTAssertTrue(state.observe(status: DeviceStatus(layerIndex: 9)))

        XCTAssertEqual(state.active, .agents)
        XCTAssertEqual(state.source, .launchDefault)
        XCTAssertEqual(state.firmwareLayerIndex, 9)
        XCTAssertFalse(state.observe(status: DeviceStatus(layerIndex: 9)))
    }
}
