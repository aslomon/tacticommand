import Foundation

actor MicroOutboundWriter {
    private var tail = Task<Void, Never> {}

    func enqueue(
        _ payload: Data,
        to transport: any MicroTransport
    ) -> Task<Void, Error> {
        let predecessor = tail
        let operation = Task {
            await predecessor.value
            try Task.checkCancellation()
            try await Self.writeFrames(payload, to: transport)
        }
        tail = Task {
            _ = await operation.result
        }
        return operation
    }

    func write(
        _ payload: Data,
        to transport: any MicroTransport
    ) async throws {
        let operation = enqueue(payload, to: transport)
        try await operation.value
    }

    private nonisolated static func writeFrames(
        _ payload: Data,
        to transport: any MicroTransport
    ) async throws {
        let frames = MicroReportFramer.frames(for: payload, transport: transport.kind)
        for report in frames {
            try Task.checkCancellation()
            try await transport.write(report)
        }
    }
}
