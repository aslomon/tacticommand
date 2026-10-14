import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

final class IOKitMicroOutputReportTests: XCTestCase {
    func testUSBAddsReportIdentifierRequiredByIOKit() throws {
        let payload = Data(#"{"method":"device.status","id":1}"#.utf8)
        let report = try XCTUnwrap(MicroReportFramer.frames(for: payload, transport: .usb).first)
        let output = try IOKitMicroOutputReport.encode(report, transport: .usb)
        XCTAssertEqual(output.count, 64)
        XCTAssertEqual(output, Data([6]) + report)
    }

    func testBluetoothDoesNotDuplicateReportIdentifier() throws {
        let report = try XCTUnwrap(
            MicroReportFramer.frames(
                for: Data("{}".utf8),
                transport: .bluetoothLowEnergy
            ).first)
        XCTAssertEqual(try IOKitMicroOutputReport.encode(report, transport: .bluetoothLowEnergy), report)
    }

    func testMalformedOutputIsRejected() {
        for kind in [MicroTransportKind.usb, .bluetoothLowEnergy] {
            XCTAssertThrowsError(try IOKitMicroOutputReport.encode(Data(), transport: kind))
            XCTAssertThrowsError(try IOKitMicroOutputReport.encode(Data(repeating: 0, count: 64), transport: kind))
        }
        var report = MicroReportFramer.frames(for: Data("{}".utf8), transport: .usb)[0]
        report[1] = 62
        XCTAssertThrowsError(try IOKitMicroOutputReport.encode(report, transport: .usb))
    }

    func testCodexKeepsVerifiedBareUSBFormat() throws {
        let report = MicroReportFramer.frames(for: Data("{}".utf8), transport: .usb)[0]
        XCTAssertEqual(try IOKitMicroOutputReport.encode(report, transport: .usb, productIdentifier: 0x8360), report)
    }
}
