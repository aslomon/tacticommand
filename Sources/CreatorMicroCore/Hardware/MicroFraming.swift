import Foundation

public enum MicroReportFramer {
    public static func frames(
        for payload: Data,
        transport: MicroTransportKind
    ) -> [Data] {
        let message = [UInt8](payload) + [0x0D, 0x0A]
        return stride(
            from: 0,
            to: message.count,
            by: MicroProtocolConstants.maximumChunkLength
        ).map { offset in
            let end = min(
                offset + MicroProtocolConstants.maximumChunkLength,
                message.count
            )
            return frame(Array(message[offset..<end]), transport: transport)
        }
    }

    private static func frame(
        _ chunk: [UInt8],
        transport: MicroTransportKind
    ) -> Data {
        let isBluetooth = transport == .bluetoothLowEnergy
        let reportLength =
            isBluetooth
            ? MicroProtocolConstants.bluetoothReportLength
            : MicroProtocolConstants.usbReportLength
        let prefixLength = isBluetooth ? 1 : 0
        var report = [UInt8](repeating: 0, count: reportLength)
        if isBluetooth {
            report[0] = MicroProtocolConstants.reportIdentifier
        }
        report[prefixLength] = MicroProtocolConstants.dataOpcode
        report[prefixLength + 1] = UInt8(chunk.count)
        report.replaceSubrange(
            (prefixLength + 2)..<(prefixLength + 2 + chunk.count),
            with: chunk
        )
        return Data(report)
    }
}

public struct MicroFrameDecoder: Sendable {
    private static let maximumBufferedLength = 65_536
    private var buffer: [UInt8] = []

    public init() {}

    public mutating func feed(_ report: Data) -> [Data] {
        guard let body = Self.body(from: [UInt8](report)) else {
            return []
        }
        buffer.append(contentsOf: body)
        guard buffer.count <= Self.maximumBufferedLength else {
            buffer.removeAll(keepingCapacity: true)
            return []
        }
        return drainMessages()
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    private static func body(from report: [UInt8]) -> ArraySlice<UInt8>? {
        let offset: Int
        if report.count >= 3,
            report[0] == MicroProtocolConstants.reportIdentifier,
            report[1] == MicroProtocolConstants.dataOpcode
        {
            offset = 1
        } else if report.count >= 2,
            report[0] == MicroProtocolConstants.dataOpcode
        {
            offset = 0
        } else {
            return nil
        }
        let count = Int(report[offset + 1])
        let bodyStart = offset + 2
        guard count <= MicroProtocolConstants.maximumChunkLength,
            report.count >= bodyStart + count
        else {
            return nil
        }
        return report[bodyStart..<(bodyStart + count)]
    }

    private mutating func drainMessages() -> [Data] {
        var messages: [Data] = []
        while let terminator = terminatorIndex() {
            let line = Data(buffer[..<terminator])
            buffer.removeFirst(terminator + 2)
            if !line.isEmpty {
                messages.append(line)
            }
        }
        return messages
    }

    private func terminatorIndex() -> Int? {
        guard buffer.count >= 2 else {
            return nil
        }
        for index in 0..<(buffer.count - 1)
        where buffer[index] == 0x0D && buffer[index + 1] == 0x0A {
            return index
        }
        return nil
    }
}
