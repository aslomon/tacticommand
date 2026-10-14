import CreatorMicroCore
import Foundation
import IOKit.hid

enum IOKitMicroOutputReport {
    static func encode(_ report: Data, transport: MicroTransportKind, productIdentifier: Int = 0x8298) throws -> Data {
        let offset = transport == .usb ? 0 : 1
        let expectedLength =
            transport == .usb
            ? MicroProtocolConstants.usbReportLength
            : MicroProtocolConstants.bluetoothReportLength
        let bytes = [UInt8](report.prefix(3))
        guard report.count == expectedLength,
            bytes[offset] == MicroProtocolConstants.dataOpcode,
            bytes[offset + 1] <= MicroProtocolConstants.maximumChunkLength,
            offset == 0 || bytes[0] == MicroProtocolConstants.reportIdentifier
        else {
            throw MicroConnectionError.outputReportFailed(code: kIOReturnBadArgument)
        }
        // Creator USB requires an in-buffer report ID; Codex keeps its verified bare buffer.
        let needsPrefix =
            transport == .usb
            && MicroProtocolConstants.creatorMicroProductIdentifiers.contains(productIdentifier)
        return needsPrefix ? Data([MicroProtocolConstants.reportIdentifier]) + report : report
    }
}
