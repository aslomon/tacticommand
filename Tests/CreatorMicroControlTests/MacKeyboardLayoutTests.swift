import XCTest

@testable import CreatorMicroControl

final class MacKeyboardLayoutTests: XCTestCase {
    func testCurrentDisplayNameComesFromTheSystemLayoutWithoutTextFocus() {
        XCTAssertNotEqual(
            MacKeyboardLayout.currentDisplayName,
            "Current macOS layout"
        )
    }

    func testDisplayNameUsesLocalizedInputSourceName() {
        XCTAssertEqual(
            MacKeyboardLayout.displayName(
                identifier: "com.apple.keylayout.German",
                localizedName: { _ in "German" }
            ),
            "German"
        )
    }

    func testDisplayNameFallsBackToReadableIdentifierSuffix() {
        XCTAssertEqual(
            MacKeyboardLayout.displayName(
                identifier: "com.apple.keylayout.German",
                localizedName: { _ in nil }
            ),
            "German"
        )
        XCTAssertEqual(
            MacKeyboardLayout.displayName(
                identifier: nil,
                localizedName: { _ in nil }
            ),
            "Current macOS layout"
        )
    }
}
