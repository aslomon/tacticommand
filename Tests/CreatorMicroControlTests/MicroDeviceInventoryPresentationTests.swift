import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class MicroDeviceInventoryPresentationTests: XCTestCase {
    func testConnectedDeviceKeepsItsObservedNameAndTransport() {
        let device = MicroDeviceRecord(
            identifier: "94A990F97774",
            name: "Codex Micro #1",
            serialNumber: "94A990F97774",
            transport: .bluetoothLowEnergy
        )

        XCTAssertEqual(device.connectionLabel, "Bluetooth")
        XCTAssertEqual(device.name, "Codex Micro #1")
    }

    func testDuplicateInterfacesCollapseIntoOnePhysicalDevice() {
        let device = MicroDeviceRecord(
            identifier: "94A990F97774",
            name: "Codex Micro #1",
            serialNumber: "94A990F97774",
            transport: .bluetoothLowEnergy
        )

        XCTAssertEqual(
            MicroDeviceInventoryPresentation.unique([device, device]),
            [device]
        )
    }

    func testBluetoothSettingsLinkUsesTheNativeSettingsExtension() {
        XCTAssertEqual(
            MicroDeviceInventoryPresentation.bluetoothSettingsURL.absoluteString,
            "x-apple.systempreferences:com.apple.Bluetooth-Settings.extension"
        )
    }

    func testHistoryKeepsNewlyObservedDevicesFirstAndUnique() {
        let bluetooth = MicroDeviceRecord(
            identifier: "bluetooth",
            name: "Codex Micro #1",
            serialNumber: nil,
            transport: .bluetoothLowEnergy
        )
        let usb = MicroDeviceRecord(
            identifier: "usb",
            name: "Creator Micro",
            serialNumber: nil,
            transport: .usb
        )

        XCTAssertEqual(
            MicroDeviceInventoryPresentation.remembering(
                [bluetooth],
                among: [usb, bluetooth]
            ),
            [bluetooth, usb]
        )
    }
}
