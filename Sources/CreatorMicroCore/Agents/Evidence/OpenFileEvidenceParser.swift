import Foundation

public struct OpenFileEvidenceParseResult: Equatable, Sendable {
    public let paths: [String]
    public let malformedLineCount: Int

    public init(paths: [String], malformedLineCount: Int) {
        self.paths = paths
        self.malformedLineCount = malformedLineCount
    }
}

public struct OpenFileEvidenceParser: Sendable {
    public init() {}

    public func parse(_ data: Data) -> OpenFileEvidenceParseResult {
        guard let output = String(data: data, encoding: .utf8) else {
            return OpenFileEvidenceParseResult(paths: [], malformedLineCount: 1)
        }
        var paths: Set<String> = []
        var malformedLineCount = 0
        for line in output.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) where line.first == "n" {
            let path = String(line.dropFirst())
            if path.isEmpty {
                malformedLineCount += 1
            } else if path.hasPrefix("/") {
                paths.insert(path)
            }
        }
        return OpenFileEvidenceParseResult(
            paths: paths.sorted(),
            malformedLineCount: malformedLineCount
        )
    }
}
