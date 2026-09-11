import CreatorMicroCore
import Foundation

public enum LocalAutomationClientFailure: Error, Equatable, Sendable {
    case encoding
    case connection(LocalAutomationServerFailure)
    case transport
    case invalidResponse
    case remote(LocalAutomationError)
}

public struct LocalAutomationClient: Sendable {
    private let socketURL: URL

    public init(socketURL: URL = LocalAutomationServer.defaultSocketURL) {
        self.socketURL = socketURL
    }

    public func call(
        _ command: LocalAutomationCommand
    ) async -> Result<LocalAutomationResult, LocalAutomationClientFailure> {
        let url = socketURL
        return await Task.detached(priority: .userInitiated) {
            await callWithStartupRetry(command, socketURL: url)
        }.value
    }

    private func callWithStartupRetry(
        _ command: LocalAutomationCommand,
        socketURL: URL
    ) async -> Result<LocalAutomationResult, LocalAutomationClientFailure> {
        var result = callBlocking(command, socketURL: socketURL)
        for delay in LocalAutomationStartupRetry.delaysNanoseconds {
            guard result.isStartupConnectionFailure else { return result }
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return result
            }
            result = callBlocking(command, socketURL: socketURL)
        }
        return result
    }

    private func callBlocking(
        _ command: LocalAutomationCommand,
        socketURL: URL
    ) -> Result<LocalAutomationResult, LocalAutomationClientFailure> {
        let request = LocalAutomationRequest(
            id: "client-\(UUID().uuidString)",
            command: command
        )
        guard let data = try? LocalAutomationCodec().encode(request) else {
            return .failure(.encoding)
        }
        let descriptor: Int32
        do {
            descriptor = try LocalAutomationSocket.connect(to: socketURL)
        } catch let failure as LocalAutomationServerFailure {
            return .failure(.connection(failure))
        } catch {
            return .failure(.transport)
        }
        defer { LocalAutomationSocket.close(descriptor) }
        guard LocalAutomationSocket.write(data + Data([0x0A]), to: descriptor) else {
            return .failure(.transport)
        }
        return readResponse(identifier: request.id, descriptor: descriptor)
    }

    private func readResponse(
        identifier: String,
        descriptor: Int32
    ) -> Result<LocalAutomationResult, LocalAutomationClientFailure> {
        var framer = LocalAutomationLineFramer()
        while let data = LocalAutomationSocket.read(descriptor) {
            for frame in framer.append(data) {
                guard case .line(let line) = frame else {
                    return .failure(.invalidResponse)
                }
                return parseResponse(line, identifier: identifier)
            }
        }
        return .failure(.transport)
    }

    private func parseResponse(
        _ data: Data,
        identifier: String
    ) -> Result<LocalAutomationResult, LocalAutomationClientFailure> {
        guard case .success(let response) = LocalAutomationCodec().decodeResponse(data),
            response.id == identifier
        else {
            return .failure(.invalidResponse)
        }
        if let error = response.error { return .failure(.remote(error)) }
        guard let result = response.result else { return .failure(.invalidResponse) }
        return .success(result)
    }
}

extension Result where Failure == LocalAutomationClientFailure {
    fileprivate var isStartupConnectionFailure: Bool {
        guard case .failure(.connection(let failure)) = self,
            case .socket(let operation, let code) = failure,
            operation == "connect"
        else {
            return false
        }
        return code == ENOENT || code == ECONNREFUSED
    }
}
