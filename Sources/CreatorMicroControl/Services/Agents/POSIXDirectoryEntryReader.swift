import Darwin
import Foundation

struct POSIXDirectoryEntryReader: Sendable {
    func children(in directoryURL: URL) throws -> [URL] {
        try directoryURL.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                throw POSIXDirectoryReadError(
                    path: directoryURL.path,
                    errorCode: EINVAL
                )
            }
            guard let directory = opendir(path) else {
                throw POSIXDirectoryReadError(
                    path: directoryURL.path,
                    errorCode: errno
                )
            }
            defer { closedir(directory) }
            return try readChildren(from: directory, parent: directoryURL)
        }
    }

    private func readChildren(
        from directory: UnsafeMutablePointer<DIR>,
        parent: URL
    ) throws -> [URL] {
        var children: [URL] = []
        while true {
            errno = 0
            guard let entry = readdir(directory) else {
                if errno != 0 {
                    throw POSIXDirectoryReadError(
                        path: parent.path,
                        errorCode: errno
                    )
                }
                return children
            }
            let name = entryName(entry)
            guard name != ".", name != ".." else { continue }
            children.append(parent.appendingPathComponent(name))
        }
    }

    private func entryName(_ entry: UnsafeMutablePointer<dirent>) -> String {
        let byteCount = Int(entry.pointee.d_namlen)
        return withUnsafeBytes(of: entry.pointee.d_name) { bytes in
            String(decoding: bytes.prefix(byteCount), as: UTF8.self)
        }
    }
}

struct POSIXDirectoryReadError: Error, Equatable, Sendable {
    let path: String
    let errorCode: Int32
}
