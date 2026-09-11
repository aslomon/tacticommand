import XCTest

@testable import CreatorMicroControl

@MainActor
final class MenuBarPopoverDesignTests: XCTestCase {
    func testPopoverUsesReadableWideLayout() {
        XCTAssertEqual(DesignTokens.popoverWidth, 392)
    }

    func testMenuBarKeepsCompactSystemSymbolInsteadOfDockArtwork() {
        XCTAssertEqual(MenuBarPopoverController.statusItemSymbolName, "circle.grid.2x2.fill")
    }
}
