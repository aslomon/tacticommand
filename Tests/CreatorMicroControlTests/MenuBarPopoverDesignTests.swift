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

    func testPopoverOpensActiveOnAnOpaqueReadableSurface() {
        XCTAssertTrue(MenuBarPopoverPresentationPolicy.activatesApplicationOnOpen)
        XCTAssertEqual(MenuBarPopoverPresentationPolicy.surfaceOpacity, 1)
        XCTAssertTrue(MenuBarPopoverPresentationPolicy.usesPrimaryStatusText)
        XCTAssertTrue(MenuBarPopoverPresentationPolicy.makesWindowOpaque)
    }

    func testPopoverQuitControlIsCompactButExplicitForVoiceOver() {
        XCTAssertEqual(ApplicationControlsPresentation.quitTitle, "Quit")
        XCTAssertEqual(ApplicationControlsPresentation.quitSystemImage, "power")
        XCTAssertEqual(
            ApplicationControlsPresentation.quitAccessibilityLabel,
            "Quit TactiCommand"
        )
        XCTAssertEqual(ApplicationControlsPresentation.quitMinimumTargetSize, 28)
    }

    func testLaunchAtLoginBelongsToConfigurationSettings() {
        XCTAssertEqual(
            ApplicationControlsPresentation.launchAtLoginPlacement,
            .configurationSettings
        )
        XCTAssertEqual(ApplicationControlsPresentation.launchAtLoginTitle, "Launch at Login")
    }
}
