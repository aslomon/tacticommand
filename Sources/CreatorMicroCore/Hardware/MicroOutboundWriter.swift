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
            if case .failure(let error) = await operation.result, error is CancellationError { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return operation
    }

    func write(
        _ payload: Data,
        to transport: any MicroTransport
    ) async throws {
        let operation = enqueue(payload, to: transport)
        try await withTaskCancellationHandler {
            try await operation.value
        } onCancel: {
            operation.cancel()
        }
    }

    func drain() async {
        let pending = tail
        await pending.value
    }

    private nonisolated static func writeFrames(
        _ payload: Data,
        to transport: any MicroTransport
    ) async throws {
        let frames = MicroReportFramer.frames(for: payload, transport: transport.kind)
        for report in frames {
            // Once started, finish the whole JSON payload; never strand half a message.
            try await transport.write(report)
        }
    }
}
