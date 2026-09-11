import XCTest

@testable import CreatorMicroControl

@MainActor
final class WorkspaceApplicationControllerTests: XCTestCase {
    func testFallsBackToWorkspaceLaunchWhenRunningApplicationActivationFails() async {
        var attemptedIdentifiers: [String] = []
        let controller = WorkspaceApplicationController(
            activateRunningApplication: { _ in false },
            launchInstalledApplication: { identifier in
                attemptedIdentifiers.append(identifier)
                return .success(())
            }
        )

        let result = await controller.activateTerminal()

        if case .failure(let failure) = result {
            XCTFail("Expected fallback launch to succeed, got \(failure)")
        }
        XCTAssertEqual(attemptedIdentifiers, ["com.apple.Terminal"])
    }

    func testDoesNotLaunchAgainWhenRunningApplicationActivationSucceeds() async {
        var launchCount = 0
        let controller = WorkspaceApplicationController(
            activateRunningApplication: { _ in true },
            launchInstalledApplication: { _ in
                launchCount += 1
                return .success(())
            }
        )

        let result = await controller.activateTerminal()

        if case .failure(let failure) = result {
            XCTFail("Expected running application activation to succeed, got \(failure)")
        }
        XCTAssertEqual(launchCount, 0)
    }
}
