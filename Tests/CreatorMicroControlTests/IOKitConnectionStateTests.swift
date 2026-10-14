import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class IOKitConnectionStateTests: XCTestCase {
    func testFirstConnectionBecomesTheOnlyActiveDevice() {
        var state = IOKitConnectionState<Int>()

        XCTAssertTrue(state.connect(7, transportKind: .usb))

        XCTAssertEqual(state.device, 7)
        XCTAssertEqual(state.transportKind, .usb)
        XCTAssertEqual(state.activeConnection?.device, 7)
    }

    func testConnectCapturesTheRealObservedProductIdentifier() {
        var state = IOKitConnectionState<Int>()

        XCTAssertTrue(state.connect(7, transportKind: .usb, productIdentifier: 0x8298))

        XCTAssertEqual(state.productIdentifier, 0x8298)

        XCTAssertTrue(state.disconnect { $0 == 7 })
        XCTAssertNil(state.productIdentifier)
    }

    func testSecondConnectionCannotOverwriteActiveDevice() {
        var state = IOKitConnectionState<Int>()
        XCTAssertTrue(state.connect(7, transportKind: .usb))

        XCTAssertFalse(state.connect(9, transportKind: .bluetoothLowEnergy))

        XCTAssertEqual(state.device, 7)
        XCTAssertEqual(state.transportKind, .usb)
        XCTAssertEqual(state.activeConnection?.device, 7)
    }

    func testReportSenderMustMatchActiveDevice() {
        var state = IOKitConnectionState<Int>()
        XCTAssertTrue(state.connect(7, transportKind: .usb))

        XCTAssertTrue(state.isActiveDevice { $0 == 7 })
        XCTAssertFalse(state.isActiveDevice { $0 == 9 })
    }

    func testRemovingInactiveDevicePreservesActiveDevice() {
        var state = IOKitConnectionState<Int>()
        XCTAssertTrue(state.connect(7, transportKind: .usb))

        XCTAssertFalse(state.disconnect { $0 == 9 })
        XCTAssertEqual(state.device, 7)
        XCTAssertEqual(state.transportKind, .usb)

        XCTAssertTrue(state.disconnect { $0 == 7 })
        XCTAssertNil(state.activeConnection)
    }

    func testCancellationClearsConnectionAndRejectsLaterConnect() {
        var state = IOKitConnectionState<Int>()
        XCTAssertTrue(state.connect(7, transportKind: .usb))
        XCTAssertEqual(state.device, 7)
        XCTAssertEqual(state.transportKind, .usb)

        XCTAssertTrue(state.beginCancellation())

        XCTAssertNil(state.device)
        XCTAssertNil(state.transportKind)
        XCTAssertNil(state.activeConnection)
        XCTAssertFalse(state.connect(9, transportKind: .bluetoothLowEnergy))
        XCTAssertFalse(state.beginCancellation())
    }

    func testRemovedTransportCannotRetargetAReplacementDevice() {
        var state = IOKitConnectionState<Int>()
        XCTAssertTrue(state.connect(7, transportKind: .usb))
        XCTAssertTrue(state.disconnect { $0 == 7 })
        XCTAssertFalse(state.connect(9, transportKind: .usb))
        XCTAssertNil(state.activeConnection)
        XCTAssertTrue(state.beginCancellation())
    }
}
