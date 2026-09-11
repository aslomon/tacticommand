import CreatorMicroCore
import Darwin
import Foundation

public enum LocalAutomationServerFailure: Error, Equatable, Sendable {
    case alreadyRunning
    case insecureDirectory
    case pathTooLong
    case socketPathOccupied
    case startupCancelled
    case socket(operation: String, code: Int32)
}

public actor LocalAutomationServer {
    public static var defaultSocketURL: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("CreatorMicroControl", isDirectory: true)
        .appendingPathComponent("Automation", isDirectory: true)
        .appendingPathComponent("control-v1.sock")
    }

    private let socketURL: URL
    private let processor: LocalAutomationRequestProcessor
    private let startupCheckpoint: @Sendable () async -> Void
    private var listener: Int32?
    private var acceptTask: Task<Void, Never>?
    private var clients: [UUID: ClientSession] = [:]
    private var startupGeneration: UInt64 = 0
    private var isStarting = false
    private var isStopping = false

    var activeClientCount: Int {
        clients.count
    }

    public init(
        socketURL: URL = LocalAutomationServer.defaultSocketURL,
        handlers: LocalAutomationHandlers
    ) {
        self.socketURL = socketURL
        self.processor = LocalAutomationRequestProcessor(handlers: handlers)
        self.startupCheckpoint = {}
    }

    init(
        socketURL: URL,
        handlers: LocalAutomationHandlers,
        startupCheckpoint: @escaping @Sendable () async -> Void
    ) {
        self.socketURL = socketURL
        self.processor = LocalAutomationRequestProcessor(handlers: handlers)
        self.startupCheckpoint = startupCheckpoint
    }

    public func start() async -> Result<URL, LocalAutomationServerFailure> {
        guard !Task.isCancelled else { return .failure(.startupCancelled) }
        guard listener == nil, !isStarting, !isStopping else {
            return .failure(.alreadyRunning)
        }
        isStarting = true
        startupGeneration &+= 1
        let generation = startupGeneration
        defer { isStarting = false }
        await processor.start()
        await startupCheckpoint()
        guard canFinishStartup(generation) else {
            await processor.stop()
            return .failure(.startupCancelled)
        }
        do {
            let descriptor = try LocalAutomationSocket.makeListener(at: socketURL)
            listener = descriptor
            acceptTask = makeAcceptTask(descriptor)
            return .success(socketURL)
        } catch let failure as LocalAutomationServerFailure {
            await processor.stop()
            return .failure(failure)
        } catch {
            await processor.stop()
            return .failure(.socket(operation: "start", code: EIO))
        }
    }

    public func stop() async {
        isStopping = true
        startupGeneration &+= 1
        await processor.stop()
        let accepting = acceptTask
        accepting?.cancel()
        acceptTask = nil
        if let listener { LocalAutomationSocket.close(listener) }
        listener = nil
        let sessions = Array(clients.values)
        for session in sessions {
            session.task.cancel()
            LocalAutomationSocket.shutdown(session.descriptor)
        }
        await accepting?.value
        for session in sessions {
            await session.task.value
        }
        clients.removeAll()
        LocalAutomationSocket.removeOwnedSocket(at: socketURL)
        isStopping = false
    }

    private func canFinishStartup(_ generation: UInt64) -> Bool {
        !Task.isCancelled
            && !isStopping
            && generation == startupGeneration
    }

    private func makeAcceptTask(_ descriptor: Int32) -> Task<Void, Never> {
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            await Self.acceptConnections(descriptor, server: self)
        }
    }

    private static func acceptConnections(
        _ listener: Int32,
        server: LocalAutomationServer
    ) async {
        while !Task.isCancelled {
            guard let client = LocalAutomationSocket.acceptClient(from: listener) else { return }
            await server.register(client)
        }
    }

    private func register(_ descriptor: Int32) {
        guard listener != nil,
            !isStopping,
            clients.count < LocalAutomationSocket.maximumClients
        else {
            LocalAutomationSocket.close(descriptor)
            return
        }
        let identifier = UUID()
        let processor = self.processor
        let task = Task.detached(priority: .utility) { [weak self] in
            await Self.serve(descriptor, processor: processor)
            await self?.clientDidFinish(identifier)
        }
        clients[identifier] = ClientSession(descriptor: descriptor, task: task)
    }

    private func clientDidFinish(_ identifier: UUID) {
        clients.removeValue(forKey: identifier)
    }

    private static func serve(
        _ descriptor: Int32,
        processor: LocalAutomationRequestProcessor
    ) async {
        defer { LocalAutomationSocket.close(descriptor) }
        guard LocalAutomationSocket.isCurrentUserPeer(descriptor) else { return }
        var framer = LocalAutomationLineFramer()
        while !Task.isCancelled,
            let data = LocalAutomationSocket.read(descriptor)
        {
            if Task.isCancelled { return }
            for frame in framer.append(data) {
                guard let response = await processor.response(for: frame),
                    send(response, to: descriptor)
                else { return }
                if case .frameTooLarge = frame { return }
            }
        }
    }

    private static func send(
        _ response: LocalAutomationResponse,
        to descriptor: Int32
    ) -> Bool {
        let codec = LocalAutomationCodec()
        guard let encoded = try? codec.encode(response) else { return false }
        let data: Data
        if encoded.count <= LocalAutomationProtocol.maximumLineBytes {
            data = encoded
        } else {
            let fallback = LocalAutomationResponse.failure(
                id: response.id,
                error: LocalAutomationError(
                    code: .internalError,
                    message: "The response exceeds the size limit."
                )
            )
            guard let fallbackData = try? codec.encode(fallback) else { return false }
            data = fallbackData
        }
        return LocalAutomationSocket.write(data + Data([0x0A]), to: descriptor)
    }
}

private struct ClientSession: Sendable {
    let descriptor: Int32
    let task: Task<Void, Never>
}
