import Foundation

public enum MicroRPCError: Error, Equatable, LocalizedError {
    case capacity, timeout, malformedResponse
    case device(code: Int, message: String)
    public var errorDescription: String? {
        switch self {
        case .capacity: "The device request limit was reached. Reconnect and try again."
        case .timeout: "The device did not answer. Reconnect and try again."
        case .malformedResponse: "The device returned an invalid response."
        case .device(let code, let message):
            "Device error \(code): \(message). Check the official firmware for your model."
        }
    }
}

struct PendingMicroRPC {
    let method: String
    let continuation: CheckedContinuation<MicroJSONValue, Error>
    let timeout: Task<Void, Never>
}

extension MicroDeviceCoordinator {
    public func request(
        method: String, parameters: MicroJSONValue = .null,
        timeout: Duration = .seconds(5), expectedConnection: UUID? = nil
    ) async throws -> MicroJSONValue {
        try Task.checkCancellation()
        guard isVerified, let transport = activeTransport,
            expectedConnection == nil || identitySnapshot?.connectionID == expectedConnection
        else { throw MicroConnectionError.notConnected }
        guard pendingRPC.count < 8, nextRPCIdentifier <= 998 else { throw MicroRPCError.capacity }
        let identifier = nextRPCIdentifier
        nextRPCIdentifier += 1
        let payload = try MicroJSONValue.object([
            "id": .number(Decimal(identifier)), "method": .string(method), "params": parameters,
        ]).encoded()
        guard payload.count < 65_000 else { throw MicroRPCError.capacity }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timer = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    await self?.finishRPC(identifier, result: .failure(MicroRPCError.timeout))
                }
                pendingRPC[identifier] = PendingMicroRPC(
                    method: method, continuation: continuation, timeout: timer)
                let writeTask = Task { [weak self] in
                    do { try await self?.write(payload, to: transport) } catch {
                        await self?.finishRPC(identifier, result: .failure(error))
                    }
                }
                rpcWriteTasks[identifier] = writeTask
                if Task.isCancelled { finishRPC(identifier, result: .failure(CancellationError())) }
            }
        } onCancel: {
            Task { await self.finishRPC(identifier, result: .failure(CancellationError())) }
        }
    }

    func receiveRPC(_ payload: Data) -> Bool {
        guard let envelope = try? JSONDecoder().decode(MicroJSONValue.self, from: payload),
            let identifier = (envelope["id"] ?? envelope["i"])?.integer,
            identifier >= 2
        else { return false }
        // Ignore late/cancelled responses; they must not become input notifications.
        guard let pending = pendingRPC[identifier] else { return true }
        guard (envelope["method"] ?? envelope["m"])?.string == pending.method else { return true }
        if let error = envelope["error"], error != .null {
            finishRPC(
                identifier,
                result: .failure(
                    MicroRPCError.device(
                        code: error["code"]?.integer ?? -1,
                        message: error["message"]?.string ?? "Unknown firmware error")))
        } else if let result = envelope["result"] {
            finishRPC(identifier, result: .success(result))
        } else {
            finishRPC(identifier, result: .failure(MicroRPCError.malformedResponse))
        }
        return true
    }

    func finishRPC(_ identifier: Int, result: Result<MicroJSONValue, Error>) {
        guard let pending = pendingRPC.removeValue(forKey: identifier) else { return }
        pending.timeout.cancel()
        rpcWriteTasks.removeValue(forKey: identifier)?.cancel()
        pending.continuation.resume(with: result)
    }

    func cancelRPC() {
        for identifier in Array(pendingRPC.keys) {
            finishRPC(identifier, result: .failure(MicroConnectionError.transportDisconnected))
        }
    }
}
