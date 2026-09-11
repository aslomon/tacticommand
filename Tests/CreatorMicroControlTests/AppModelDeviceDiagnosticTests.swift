import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelDeviceDiagnosticTests: XCTestCase {
    func testVerifiedConnectionClearsOnlyThePreviousDeviceDiagnostic() async {
        let model = AppModel()

        await model.consume(.diagnostic("Old device warning"))
        XCTAssertEqual(model.lastError, "Old device warning")

        await model.consume(
            .connection(
                .connected(
                    transport: .bluetoothLowEnergy,
                    status: DeviceStatus(version: "test")
                )
            )
        )
        XCTAssertNil(model.lastError)
    }

    func testVerifiedConnectionPreservesAnUnrelatedError() async {
        let model = AppModel()

        await model.consume(.diagnostic("Old device warning"))
        model.lastError = "Shortcut failed"
        await model.consume(
            .connection(
                .connected(
                    transport: .usb,
                    status: DeviceStatus(version: "test")
                )
            )
        )

        XCTAssertEqual(model.lastError, "Shortcut failed")
    }

    func testSuccessfulActionClearsAStaleActionError() async {
        let model = AppModel()
        model.lastError = "Application could not be focused: com.apple.Terminal"

        await model.execute(.init(action: .none, phase: .pressed))

        XCTAssertNil(model.lastError)
    }

    func testSuccessfulActionPreservesTheCurrentDeviceDiagnostic() async {
        let model = AppModel()
        await model.consume(.diagnostic("Device transport warning"))

        await model.execute(.init(action: .none, phase: .pressed))

        XCTAssertEqual(model.lastError, "Device transport warning")
    }

    func testValidDeviceEventClearsAStaleDeviceDiagnostic() async {
        let model = AppModel()
        await model.consume(.diagnostic("A malformed device message was ignored."))

        await model.consume(.event(.unhandled(method: "response")))

        XCTAssertNil(model.lastError)
    }

    func testValidDeviceEventPreservesAnUnrelatedActionError() async {
        let model = AppModel()
        await model.consume(.diagnostic("A malformed device message was ignored."))
        model.lastError = "Shortcut failed"

        await model.consume(.event(.unhandled(method: "response")))

        XCTAssertEqual(model.lastError, "Shortcut failed")
    }
}
