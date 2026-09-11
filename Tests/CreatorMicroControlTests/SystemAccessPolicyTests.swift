import XCTest

@testable import CreatorMicroControl

final class SystemAccessPolicyTests: XCTestCase {
    func testAccessibilitySettingsArePreferredWhenBothPermissionsAreMissing() {
        let access = SystemAccessSnapshot(accessibility: .denied, inputMonitoring: .denied)

        let pane = SystemAccessPolicy.requiredPrivacyPane(for: access)

        XCTAssertEqual(pane, .accessibility)
        XCTAssertEqual(
            pane?.url.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    func testInputMonitoringSettingsAreUsedAfterAccessibilityIsGranted() {
        let access = SystemAccessSnapshot(accessibility: .granted, inputMonitoring: .denied)

        let pane = SystemAccessPolicy.requiredPrivacyPane(for: access)

        XCTAssertEqual(pane, .inputMonitoring)
        XCTAssertEqual(
            pane?.url.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        )
    }

    func testCompleteAccessNeedsNoPrivacySettingsLink() {
        let access = SystemAccessSnapshot(accessibility: .granted, inputMonitoring: .granted)

        XCTAssertNil(SystemAccessPolicy.requiredPrivacyPane(for: access))
        XCTAssertTrue(SystemAccessPolicy.canStartDeviceRuntime(with: access))
    }
}
