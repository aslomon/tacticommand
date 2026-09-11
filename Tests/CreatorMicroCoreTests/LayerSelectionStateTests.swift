import XCTest

@testable import CreatorMicroCore

final class LayerSelectionStateTests: XCTestCase {
    func testLayerCommandsWrapAcrossAllSixSoftwareLayers() {
        XCTAssertEqual(LayerCommand.next.destination(from: .snippets), .codex)
        XCTAssertEqual(LayerCommand.previous.destination(from: .codex), .snippets)
        XCTAssertEqual(LayerCommand.select(.meetings).destination(from: .desktop), .meetings)
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
