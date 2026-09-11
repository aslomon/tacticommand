import XCTest

@testable import CreatorMicroControl

final class LayerIntentMappingTests: XCTestCase {
    func testLayerIntentValuesPreserveIdentifiersAndMapToTenSoftwareLayers() {
        XCTAssertEqual(CreatorMicroLayerIntentValue.desktop.layer, .desktop)
        XCTAssertEqual(CreatorMicroLayerIntentValue.agents.layer, .agentFocus)
        XCTAssertEqual(CreatorMicroLayerIntentValue.windows.layer, .windowManagement)
        XCTAssertEqual(CreatorMicroLayerIntentValue.meetings.layer, .meetingControls)
        XCTAssertEqual(CreatorMicroLayerIntentValue.snippets.layer, .snippetCommands)
        XCTAssertEqual(CreatorMicroLayerIntentValue.cursor.layer, .cursor)
        XCTAssertEqual(CreatorMicroLayerIntentValue.meetingControls.layer, .meetingControls)
        XCTAssertEqual(CreatorMicroLayerIntentValue.codex.layer, .codexCLI)
        XCTAssertEqual(CreatorMicroLayerIntentValue.claudeCodeCLI.layer, .claudeCodeCLI)
        XCTAssertEqual(CreatorMicroLayerIntentValue.claudeApp.layer, .claudeApp)
        XCTAssertEqual(CreatorMicroLayerIntentValue.codexCLI.layer, .codexCLI)
        XCTAssertEqual(CreatorMicroLayerIntentValue.codexApp.layer, .codexApp)
        XCTAssertEqual(CreatorMicroLayerIntentValue.agentFocus.layer, .agentFocus)
        XCTAssertEqual(CreatorMicroLayerIntentValue.windowManagement.layer, .windowManagement)
        XCTAssertEqual(CreatorMicroLayerIntentValue.snippetCommands.layer, .snippetCommands)
    }
}
