import Foundation
import XCTest

@testable import CreatorMicroControl

final class AgentEvidenceFileScannerTests: XCTestCase {
    func testPOSIXReaderEnumeratesDirectoryChildren() throws {
        let root = try makeFixture(directoryCount: 2, fileCount: 3)
        defer { try? FileManager.default.removeItem(at: root) }

        let children = try POSIXDirectoryEntryReader().children(in: root)

        XCTAssertEqual(Set(children.map(\.lastPathComponent)), ["group-0", "group-1"])
    }

    func testConcurrentScansReturnStableCompleteSnapshots() async throws {
        let directoryCount = 8
        let fileCount = 12
        let expectedCount = directoryCount * fileCount
        let root = try makeFixture(
            directoryCount: directoryCount,
            fileCount: fileCount
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let scanner = RecentAgentEvidenceFileScanner()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    for _ in 0..<20 {
                        let scan = try scanner.scan(
                            root: root,
                            newerThan: .distantPast,
                            maximumDepth: 1,
                            maximumCount: expectedCount
                        )
                        try Self.validate(scan: scan, expectedCount: expectedCount)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private static func validate(
        scan: AgentEvidenceFileScan,
        expectedCount: Int
    ) throws {
        guard scan.files.count == expectedCount else {
            throw ScannerRegressionFailure.unexpectedCount(scan.files.count)
        }
        let paths = Set(scan.files.map { $0.url.standardizedFileURL.path })
        guard paths.count == expectedCount else {
            throw ScannerRegressionFailure.duplicatePaths
        }
        guard !scan.hadUnreadableEntries else {
            throw ScannerRegressionFailure.unreadableEntries
        }
    }

    private func makeFixture(
        directoryCount: Int,
        fileCount: Int
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        for directoryIndex in 0..<directoryCount {
            let directory = root.appendingPathComponent(
                "group-\(directoryIndex)",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try makeFiles(count: fileCount, in: directory)
        }
        return root
    }

    private func makeFiles(count: Int, in directory: URL) throws {
        for fileIndex in 0..<count {
            let file = directory.appendingPathComponent("session-\(fileIndex).jsonl")
            try Data("{}\n".utf8).write(to: file)
        }
    }
}

private enum ScannerRegressionFailure: Error {
    case unexpectedCount(Int)
    case duplicatePaths
    case unreadableEntries
}
