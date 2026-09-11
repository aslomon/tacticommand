import CreatorMicroCore
import Foundation

struct AgentEvidenceFile: Equatable, Sendable {
    let url: URL
    let modificationDate: Date
}

struct AgentEvidenceFileScan: Sendable {
    let files: [AgentEvidenceFile]
    let hadUnreadableEntries: Bool
}

struct RecentAgentEvidenceFileScanner: Sendable {
    private let directoryReader = POSIXDirectoryEntryReader()

    func scan(
        root: URL,
        newerThan cutoff: Date,
        maximumDepth: Int,
        maximumCount: Int
    ) throws -> AgentEvidenceFileScan {
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw AgentSessionAdapterError.sourceUnavailable
        }
        let scan = traverse(
            root: root,
            cutoff: cutoff,
            maximumDepth: maximumDepth
        )
        let newest = scan.files.sorted(by: isNewerEvidence)
        return AgentEvidenceFileScan(
            files: Array(newest.prefix(max(maximumCount, 0))),
            hadUnreadableEntries: scan.hadUnreadableEntries
        )
    }

    private func traverse(
        root: URL,
        cutoff: Date,
        maximumDepth: Int
    ) -> AgentEvidenceFileScan {
        var pending = [(url: root, depth: 0)]
        var files: [AgentEvidenceFile] = []
        var hadUnreadableEntries = false

        while let directory = pending.popLast() {
            do {
                let children = try directoryReader.children(in: directory.url)
                let foundUnreadableEntry = inspect(
                    children,
                    depth: directory.depth,
                    maximumDepth: maximumDepth,
                    cutoff: cutoff,
                    pending: &pending,
                    files: &files
                )
                hadUnreadableEntries = hadUnreadableEntries || foundUnreadableEntry
            } catch {
                hadUnreadableEntries = true
            }
        }

        return AgentEvidenceFileScan(
            files: files,
            hadUnreadableEntries: hadUnreadableEntries
        )
    }

    private func inspect(
        _ children: [URL],
        depth: Int,
        maximumDepth: Int,
        cutoff: Date,
        pending: inout [(url: URL, depth: Int)],
        files: inout [AgentEvidenceFile]
    ) -> Bool {
        var hadUnreadableEntry = false
        for child in children {
            guard !isHidden(child) else { continue }
            do {
                try inspect(
                    child,
                    depth: depth,
                    maximumDepth: maximumDepth,
                    cutoff: cutoff,
                    pending: &pending,
                    files: &files
                )
            } catch {
                hadUnreadableEntry = true
            }
        }
        return hadUnreadableEntry
    }

    private func inspect(
        _ child: URL,
        depth: Int,
        maximumDepth: Int,
        cutoff: Date,
        pending: inout [(url: URL, depth: Int)],
        files: inout [AgentEvidenceFile]
    ) throws {
        let values = try child.resourceValues(
            forKeys: [
                .isDirectoryKey,
                .isPackageKey,
                .contentModificationDateKey,
            ]
        )
        if values.isDirectory == true {
            if depth < maximumDepth && values.isPackage != true {
                pending.append((child, depth + 1))
            }
            return
        }
        guard child.pathExtension == "jsonl" else { return }
        guard let modificationDate = values.contentModificationDate else {
            throw AgentEvidenceInspectionError.missingModificationDate
        }
        guard modificationDate >= cutoff else { return }
        files.append(
            AgentEvidenceFile(url: child, modificationDate: modificationDate)
        )
    }

    private func isHidden(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".")
    }

    private func isNewerEvidence(
        _ left: AgentEvidenceFile,
        _ right: AgentEvidenceFile
    ) -> Bool {
        if left.modificationDate != right.modificationDate {
            return left.modificationDate > right.modificationDate
        }
        return left.url.path < right.url.path
    }
}

private enum AgentEvidenceInspectionError: Error {
    case missingModificationDate
}

struct BoundedAgentEvidenceReader: Sendable {
    let headerByteCount: Int
    let tailByteCount: Int

    init(headerByteCount: Int = 65_536, tailByteCount: Int = 262_144) {
        self.headerByteCount = max(headerByteCount, 1)
        self.tailByteCount = max(tailByteCount, 1)
    }

    func read(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }
        let size = try handle.seekToEnd()
        let combinedLimit = UInt64(headerByteCount + tailByteCount)
        if size <= combinedLimit {
            try handle.seek(toOffset: 0)
            return try handle.readToEnd() ?? Data()
        }

        try handle.seek(toOffset: 0)
        var data = try handle.read(upToCount: headerByteCount) ?? Data()
        data.append(0x0A)
        try handle.seek(toOffset: size - UInt64(tailByteCount))
        data.append(try handle.read(upToCount: tailByteCount) ?? Data())
        return data
    }
}

struct OpenAgentEvidenceScanner: Sendable {
    func scan(_ files: [AgentEvidenceFile]) -> OpenAgentEvidenceScan {
        guard !files.isEmpty else {
            return OpenAgentEvidenceScan(paths: [], isReliable: true)
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-n", "-Fpn", "--"] + files.map(\.url.path)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard
                process.terminationStatus == 0
                    || process.terminationStatus == 1
            else {
                return OpenAgentEvidenceScan(paths: [], isReliable: false)
            }
            let parsed = OpenFileEvidenceParser().parse(data)
            return OpenAgentEvidenceScan(paths: Set(parsed.paths), isReliable: true)
        } catch {
            return OpenAgentEvidenceScan(paths: [], isReliable: false)
        }
    }
}

struct OpenAgentEvidenceScan: Sendable {
    let paths: Set<String>
    let isReliable: Bool
}
