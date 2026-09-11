import Foundation

public enum LocalAutomationFrame: Equatable, Sendable {
    case line(Data)
    case frameTooLarge
}

public struct LocalAutomationLineFramer: Sendable {
    private let maximumLineBytes: Int
    private var buffer = Data()
    private var discardsUntilNewline = false

    public init(maximumLineBytes: Int = LocalAutomationProtocol.maximumLineBytes) {
        self.maximumLineBytes = max(1, maximumLineBytes)
    }

    public mutating func append(_ data: Data) -> [LocalAutomationFrame] {
        var frames: [LocalAutomationFrame] = []
        for byte in data {
            if discardsUntilNewline {
                if byte == Self.lineFeed { discardsUntilNewline = false }
                continue
            }
            if byte == Self.lineFeed {
                frames.append(.line(completedLine()))
                continue
            }
            guard buffer.count < maximumLineBytes else {
                buffer.removeAll(keepingCapacity: true)
                discardsUntilNewline = true
                frames.append(.frameTooLarge)
                continue
            }
            buffer.append(byte)
        }
        return frames
    }

    private mutating func completedLine() -> Data {
        if buffer.last == Self.carriageReturn { buffer.removeLast() }
        let line = buffer
        buffer.removeAll(keepingCapacity: true)
        return line
    }

    private static let lineFeed: UInt8 = 0x0A
    private static let carriageReturn: UInt8 = 0x0D
}
