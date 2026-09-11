import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class LayerSelectionPresentationTests: XCTestCase {
    func testLocalPhysicalChangeIsExplicitlyLocal() {
        var state = LayerSelectionState(active: .desktop)
        state.select(.agents, source: .physicalKey)

        let presentation = LayerSelectionPresentation(
            state: state,
            layerName: "Agents"
        )

        XCTAssertEqual(presentation.status, "Local · Key")
        XCTAssertTrue(presentation.detail.contains("not sent to firmware"))
    }

    func testEveryLocalSelectionSourceHasConcreteStatusCopy() {
        let expected: [(LayerSelectionSource, String)] = [
            (.launchDefault, "Default"),
            (.editor, "Editor"),
            (.physicalKey, "Key"),
            (.applicationRule, "App rule"),
            (.automation, "Automation"),
        ]

        for (source, label) in expected {
            let presentation = LayerSelectionPresentation(
                state: LayerSelectionState(active: .desktop, source: source),
                layerName: "Desktop"
            )
            XCTAssertEqual(presentation.sourceLabel, label)
            XCTAssertEqual(presentation.status, "Local · \(label)")
        }
    }

    func testDeviceLayerIndexIsPresentedOnlyAsAnUnmappedObservation() {
        var state = LayerSelectionState(active: .desktop, source: .physicalKey)
        _ = state.observe(status: DeviceStatus(layerIndex: 4))

        let presentation = LayerSelectionPresentation(state: state, layerName: "Desktop")

        XCTAssertEqual(presentation.status, "Local · Key")
        XCTAssertTrue(presentation.firmwareObservation?.contains("internal layer index 4") == true)
        XCTAssertTrue(presentation.firmwareObservation?.contains("not mapped") == true)
        XCTAssertFalse(presentation.firmwareObservation?.contains("confirmed") == true)
    }

    func testPhysicalProfileExplanationSeparatesHostAndSoftwareLayers() {
        XCTAssertTrue(LayerSelectionPresentation.physicalControlExplanation.contains("Bluetooth host"))
        XCTAssertTrue(LayerSelectionPresentation.physicalControlExplanation.contains("does not change"))
        XCTAssertTrue(LayerSelectionPresentation.physicalControlExplanation.contains("cannot be assigned"))
    }
}
