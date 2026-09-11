import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

@MainActor
final class LayerChangeHUDPresenterTests: XCTestCase {
    func testContentBuildsAConciseActiveAndNextHierarchy() {
        let content = LayerChangeHUDContent(
            presentation: LayerChangeHUDPresentation(
                activeLayerName: "Desktop",
                nextLayerName: "Codex",
                source: .physicalKey
            )
        )

        XCTAssertEqual(content.eyebrow, "ACTIVE LAYER")
        XCTAssertEqual(content.activeLayerName, "Desktop")
        XCTAssertEqual(content.nextLayerLabel, "NEXT · CODEX")
        XCTAssertEqual(content.sourceLabel, "KEY")
        XCTAssertEqual(
            content.accessibilityLabel,
            "Layer Desktop active. Next layer Codex. Selected by key."
        )
    }

    func testBrandMarkUsesTheFourDotTactiCommandGeometry() {
        XCTAssertEqual(LayerChangeHUDBrandMark.dotCount, 4)
        XCTAssertEqual(LayerChangeHUDBrandMark.columns, 2)
        XCTAssertEqual(LayerChangeHUDBrandMark.rows, 2)
    }

    func testEverySelectionSourceHasACompactLabel() {
        let expected: [(LayerSelectionSource, String)] = [
            (.launchDefault, "DEFAULT"),
            (.editor, "EDITOR"),
            (.physicalKey, "KEY"),
            (.applicationRule, "APP RULE"),
            (.automation, "AUTOMATION"),
        ]

        for (source, label) in expected {
            let content = LayerChangeHUDContent(
                presentation: LayerChangeHUDPresentation(
                    activeLayerName: "Desktop",
                    nextLayerName: "Codex",
                    source: source
                )
            )

            XCTAssertEqual(content.sourceLabel, label)
        }
    }

    func testShowingHUDPostsItsCompleteAccessibilityAnnouncement() {
        let announcer = RecordingLayerChangeHUDAccessibilityAnnouncer()
        let presenter = LayerChangeHUDPresenter(accessibilityAnnouncer: announcer)

        presenter.show(
            LayerChangeHUDPresentation(
                activeLayerName: "Agent Focus",
                nextLayerName: "Desktop",
                source: .editor
            )
        )

        XCTAssertEqual(
            announcer.messages,
            ["Layer Agent Focus active. Next layer Desktop. Selected by the editor."]
        )
    }
}

@MainActor
private final class RecordingLayerChangeHUDAccessibilityAnnouncer:
    LayerChangeHUDAccessibilityAnnouncing
{
    private(set) var messages: [String] = []

    func announce(_ message: String) {
        messages.append(message)
    }
}
