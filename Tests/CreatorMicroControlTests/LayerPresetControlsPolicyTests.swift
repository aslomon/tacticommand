import XCTest

@testable import CreatorMicroControl

final class LayerPresetControlsPolicyTests: XCTestCase {
    func testLayerSwitchCommitsOnlyAnActivelyEditedName() {
        XCTAssertTrue(LayerNameEditingPolicy.shouldCommitOnLayerChange(isEditing: true))
        XCTAssertFalse(LayerNameEditingPolicy.shouldCommitOnLayerChange(isEditing: false))
    }

    func testLayerRailScrollsWhenAnotherLayerBecomesActive() {
        XCTAssertTrue(
            LayerRailScrollPolicy.shouldScroll(
                from: .desktop,
                to: .snippetCommands
            )
        )
        XCTAssertFalse(
            LayerRailScrollPolicy.shouldScroll(
                from: .snippetCommands,
                to: .snippetCommands
            )
        )
    }

    func testLayerRailInitiallyTargetsTheActiveLayer() {
        XCTAssertEqual(
            LayerRailScrollPolicy.initialTarget(activeLayer: .snippetCommands),
            .snippetCommands
        )
    }
}
