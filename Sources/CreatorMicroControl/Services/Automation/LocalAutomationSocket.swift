import CreatorMicroCore
import Darwin
import Foundation

enum LocalAutomationSocket {
    static let maximumClients = 8

    static func makeListener(at url: URL) throws -> Int32 {
        try prepareDirectory(url.deletingLastPathComponent())
        try removeStaleOwnedSocket(at: url)
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw socketError("create") }
        do {
            try configure(descriptor)
            try bind(descriptor, to: url)
            guard chmod(url.path, 0o600) == 0 else { throw socketError("secure") }
            guard Darwin.listen(descriptor, 8) == 0 else { throw socketError("listen") }
            return descriptor
        } catch {
            Darwin.close(descriptor)
            removeOwnedSocket(at: url)
            throw error
        }
    }

    static func acceptClient(from listener: Int32) -> Int32? {
        while true {
            let descriptor = Darwin.accept(listener, nil, nil)
            if descriptor >= 0 {
                do {
                    try configure(descriptor)
                    return descriptor
                } catch {
                    Darwin.close(descriptor)
                    continue
                }
            }
            if errno != EINTR { return nil }
        }
    }

    static func connect(to url: URL) throws -> Int32 {
        let descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw socketError("create client") }
        do {
            try configure(descriptor)
            var address = try address(for: url)
            let result = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(
                        descriptor,
                        $0,
                        socklen_t(MemoryLayout<sockaddr_un>.size)
                    )
                }
            }
            guard result == 0 else { throw socketError("connect") }
            return descriptor
        } catch {
            Darwin.close(descriptor)
            throw error
        }
    }

    static func isCurrentUserPeer(_ descriptor: Int32) -> Bool {
        var userID: uid_t = 0
        var groupID: gid_t = 0
        guard getpeereid(descriptor, &userID, &groupID) == 0 else { return false }
        return userID == geteuid()
    }

    static func read(_ descriptor: Int32) -> Data? {
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, bytes.count)
            }
            if count > 0 { return Data(buffer.prefix(count)) }
            if count == 0 { return nil }
            if errno != EINTR { return nil }
        }
    }

    static func write(_ data: Data, to descriptor: Int32) -> Bool {
        var offset = 0
        while offset < data.count {
            let count = data.withUnsafeBytes { bytes in
                Darwin.write(
                    descriptor,
                    bytes.baseAddress?.advanced(by: offset),
                    data.count - offset
                )
            }
            if count > 0 {
                offset += count
            } else if count < 0, errno == EINTR {
                continue
            } else {
                return false
            }
        }
        return true
    }

    static func close(_ descriptor: Int32) {
        Darwin.shutdown(descriptor, SHUT_RDWR)
        Darwin.close(descriptor)
    }

    static func shutdown(_ descriptor: Int32) {
        Darwin.shutdown(descriptor, SHUT_RDWR)
    }

    static func removeOwnedSocket(at url: URL) {
        let entry = socketEntry(at: url)
        guard case .currentUserSocket = entry,
            probe(entry, at: url) == .refused,
            socketEntry(at: url) == entry
        else { return }
        unlink(url.path)
    }

    private static func prepareDirectory(_ url: URL) throws {
        if case .missing = directoryEntry(at: url) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: url.path
            )
        }
        guard case .secure = directoryEntry(at: url) else {
            throw LocalAutomationServerFailure.insecureDirectory
        }
    }

    private static func directoryEntry(at url: URL) -> DirectoryEntry {
        var metadata = stat()
        let result = url.path.withCString { path in lstat(path, &metadata) }
        guard result == 0 else { return errno == ENOENT ? .missing : .unsafe }
        let kind = metadata.st_mode & mode_t(S_IFMT)
        let permissions = metadata.st_mode & 0o777
        guard kind == mode_t(S_IFDIR),
            metadata.st_uid == geteuid(),
            permissions == 0o700
        else { return .unsafe }
        return .secure
    }

    private static func removeStaleOwnedSocket(at url: URL) throws {
        let entry = socketEntry(at: url)
        let decision = LocalAutomationSocketPathPolicy.decision(
            ownership: entry.ownership,
            probe: probe(entry, at: url)
        )
        switch decision {
        case .create:
            return
        case .rejectOccupied:
            throw LocalAutomationServerFailure.socketPathOccupied
        case .removeStale:
            guard socketEntry(at: url) == entry else {
                throw LocalAutomationServerFailure.socketPathOccupied
            }
            guard unlink(url.path) == 0 else { throw socketError("remove stale") }
        }
    }

    private static func socketEntry(at url: URL) -> SocketEntry {
        var metadata = stat()
        let result = url.path.withCString { path in lstat(path, &metadata) }
        guard result == 0 else { return errno == ENOENT ? .missing : .unsafe }
        let kind = metadata.st_mode & mode_t(S_IFMT)
        guard kind == mode_t(S_IFSOCK), metadata.st_uid == geteuid() else { return .unsafe }
        return .currentUserSocket(
            SocketIdentity(device: metadata.st_dev, inode: metadata.st_ino)
        )
    }

    private static func probe(
        _ entry: SocketEntry,
        at url: URL
    ) -> LocalAutomationSocketProbe {
        guard case .currentUserSocket = entry else { return .notNeeded }
        do {
            let descriptor = try connect(to: url)
            close(descriptor)
            return .reachable
        } catch let failure as LocalAutomationServerFailure {
            guard case .socket(let operation, let code) = failure,
                operation == "connect"
            else { return .indeterminate }
            return code == ECONNREFUSED || code == ENOENT ? .refused : .indeterminate
        } catch {
            return .indeterminate
        }
    }

    private static func configure(_ descriptor: Int32) throws {
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) == 0 else {
            throw socketError("close-on-exec")
        }
        var enabled: Int32 = 1
        guard
            setsockopt(
                descriptor,
                SOL_SOCKET,
                SO_NOSIGPIPE,
                &enabled,
                socklen_t(MemoryLayout<Int32>.size)
            ) == 0
        else {
            throw socketError("no-sigpipe")
        }
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        guard
            setsockopt(
                descriptor,
                SOL_SOCKET,
                SO_RCVTIMEO,
                &timeout,
                socklen_t(MemoryLayout<timeval>.size)
            ) == 0
        else {
            throw socketError("receive-timeout")
        }
        guard
            setsockopt(
                descriptor,
                SOL_SOCKET,
                SO_SNDTIMEO,
                &timeout,
                socklen_t(MemoryLayout<timeval>.size)
            ) == 0
        else {
            throw socketError("send-timeout")
        }
    }

    private static func bind(_ descriptor: Int32, to url: URL) throws {
        var address = try address(for: url)
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else { throw socketError("bind") }
    }

    private static func address(for url: URL) throws -> sockaddr_un {
        var address = sockaddr_un()
        let pathBytes = Array(url.path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < capacity else { throw LocalAutomationServerFailure.pathTooLong }
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
            bytes.copyBytes(from: pathBytes)
        }
        return address
    }

    private static func socketError(_ operation: String) -> LocalAutomationServerFailure {
        .socket(operation: operation, code: errno)
    }

    private enum SocketEntry: Equatable {
        case missing
        case currentUserSocket(SocketIdentity)
        case unsafe

        var ownership: LocalAutomationSocketOwnership {
            switch self {
            case .missing: .missing
            case .currentUserSocket: .currentUserSocket
            case .unsafe: .unsafe
            }
        }
    }

    private enum DirectoryEntry {
        case missing
        case secure
        case unsafe
    }

    private struct SocketIdentity: Equatable {
        let device: dev_t
        let inode: ino_t
    }
}
