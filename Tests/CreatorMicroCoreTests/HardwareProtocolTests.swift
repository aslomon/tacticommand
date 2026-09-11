import Foundation
import XCTest

@testable import CreatorMicroCore

final class MicroReportFramingTests: XCTestCase {
    func testUSBFrameUsesBareSixtyThreeByteReport() {
        let payload = Data(#"{"m":"device.status","id":7}"#.utf8)

        let reports = MicroReportFramer.frames(for: payload, transport: .usb)

        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports[0].count, MicroProtocolConstants.usbReportLength)
        XCTAssertEqual(Array(reports[0].prefix(2)), [0x02, UInt8(payload.count + 2)])
        XCTAssertEqual(
            Data(reports[0][2..<(payload.count + 4)]),
            payload + Data([0x0D, 0x0A])
        )
    }

    func testBluetoothFramePrefixesReportIdentifier() {
        let payload = Data(#"{"m":"device.status","id":7}"#.utf8)

        let reports = MicroReportFramer.frames(
            for: payload,
            transport: .bluetoothLowEnergy
        )

        XCTAssertEqual(reports.count, 1)
        XCTAssertEqual(reports[0].count, MicroProtocolConstants.bluetoothReportLength)
        XCTAssertEqual(
            Array(reports[0].prefix(3)),
            [MicroProtocolConstants.reportIdentifier, 0x02, UInt8(payload.count + 2)]
        )
        XCTAssertEqual(
            Data(reports[0][3..<(payload.count + 5)]),
            payload + Data([0x0D, 0x0A])
        )
    }

    func testLongMessageIsSplitWithoutChangingItsBytes() {
        let payload = Data(repeating: 0xF0, count: MicroProtocolConstants.maximumChunkLength * 2)
        let reports = MicroReportFramer.frames(for: payload, transport: .usb)
        var decoder = MicroFrameDecoder()

        let decoded = reports.flatMap { decoder.feed($0) }

        XCTAssertEqual(reports.count, 3)
        XCTAssertEqual(decoded, [payload])
    }

    func testDecoderAcceptsReportIdentifierOnIncomingUSBCallback() {
        let payload = Data(#"{"m":"v.oai.hid","p":{"k":"AG02","act":1}}"#.utf8)
        let bareReport = MicroReportFramer.frames(for: payload, transport: .usb)[0]
        let callbackReport = Data([MicroProtocolConstants.reportIdentifier]) + bareReport
        var decoder = MicroFrameDecoder()

        XCTAssertEqual(decoder.feed(callbackReport), [payload])
    }

    func testDecoderIgnoresMalformedReportsAndRecovers() {
        var decoder = MicroFrameDecoder()
        let validPayload = Data(#"{"m":"device.status"}"#.utf8)
        let validReport = MicroReportFramer.frames(for: validPayload, transport: .usb)[0]

        XCTAssertTrue(decoder.feed(Data([0x00, 0x00, 0x00])).isEmpty)
        XCTAssertTrue(decoder.feed(Data([0x02, 0x3D, 0x01])).isEmpty)
        XCTAssertEqual(decoder.feed(validReport), [validPayload])
    }
}

final class SoftwareLayerIndexTests: XCTestCase {
    func testLayerIndexAcceptsExactlySixSoftwareLayers() {
        XCTAssertEqual((0..<6).compactMap(LayerIndex.init(rawValue:)).count, 6)
        XCTAssertNil(LayerIndex(rawValue: -1))
        XCTAssertNil(LayerIndex(rawValue: 6))
    }
}

final class SimulatedMicroTransportTests: XCTestCase {
    func testCapturesWritesAndStreamsInjectedReports() async throws {
        let transport = SimulatedMicroTransport(kind: .bluetoothLowEnergy)
        let report = Data([0x06, 0x02, 0x00])
        let incoming = transport.incomingReports

        try await transport.write(report)
        await transport.injectIncoming(report)
        var iterator = incoming.makeAsyncIterator()
        let received = await iterator.next()
        let writes = await transport.capturedWrites()

        XCTAssertEqual(received, report)
        XCTAssertEqual(writes, [report])
    }
}
