import XCTest

@testable import CreatorMicroControl
@testable import CreatorMicroCore

final class MicroKeyPresentationTests: XCTestCase {
    func testAgentSessionsAppearOnlyOnAgentFocusLayer() {
        XCTAssertTrue(
            MicroKeyPresentationPolicy.showsAgentSession(
                for: .agent0,
                activeLayer: .agentFocus
            )
        )
        XCTAssertFalse(
            MicroKeyPresentationPolicy.showsAgentSession(
                for: .agent0,
                activeLayer: .claudeCodeCLI
            )
        )
        XCTAssertFalse(
            MicroKeyPresentationPolicy.showsAgentSession(
                for: .agent0,
                activeLayer: .desktop
            )
        )
    }

    func testNonAgentControlsNeverShowAgentSessions() {
        XCTAssertFalse(
            MicroKeyPresentationPolicy.showsAgentSession(
                for: .action8,
                activeLayer: .agentFocus
            )
        )
    }
}
