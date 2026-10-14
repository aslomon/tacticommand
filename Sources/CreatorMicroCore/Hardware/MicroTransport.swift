import Foundation

public protocol MicroTransport: Sendable {
    var kind: MicroTransportKind { get }
    var productIdentifier: Int? { get }
    var incomingReports: AsyncStream<Data> { get }

    func write(_ report: Data) async throws
    func close() async
}

extension MicroTransport {
    public func close() async {}
    public var productIdentifier: Int? { nil }
}

public actor SimulatedMicroTransport: MicroTransport {
    public nonisolated let kind: MicroTransportKind
    public nonisolated let productIdentifier: Int?
    public nonisolated let incomingReports: AsyncStream<Data>

    private let continuation: AsyncStream<Data>.Continuation
    private var writes: [Data] = []

    public init(kind: MicroTransportKind = .usb, productIdentifier: Int? = nil) {
        self.kind = kind
        self.productIdentifier = productIdentifier
        let stream = AsyncStream<Data>.makeStream()
        incomingReports = stream.stream
        continuation = stream.continuation
    }

    public func write(_ report: Data) async throws {
        writes.append(report)
    }

    public func injectIncoming(_ report: Data) {
        continuation.yield(report)
    }

    public func injectMessage(_ payload: Data) {
        for report in MicroReportFramer.frames(for: payload, transport: kind) {
            continuation.yield(report)
        }
    }

    public func capturedWrites() -> [Data] {
        writes
    }

    public func clearCapturedWrites() {
        writes.removeAll(keepingCapacity: true)
    }

    public func finishIncomingReports() {
        continuation.finish()
    }

    public func close() async {
        continuation.finish()
    }
}
