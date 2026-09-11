import AppKit
import CreatorMicroCore
import Foundation

public struct WorkspaceInstalledApplicationCatalog:
    CreatorMicroCore.InstalledApplicationCatalog,
    Sendable
{
    private let searchRoots: [URL]

    public init(searchRoots: [URL] = Self.defaultSearchRoots) {
        self.searchRoots = searchRoots
    }

    public func installedApplications()
        async -> Result<[InstalledApplication], InstalledApplicationCatalogFailure>
    {
        let discovered = await Task.detached(priority: .utility) {
            Self.discoverApplications(in: searchRoots)
        }.value
        switch discovered {
        case .success(let applications):
            let registered = await MainActor.run {
                Self.registeredApplications(applications)
            }
            return .success(registered)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    public static var defaultSearchRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    private static func discoverApplications(
        in roots: [URL]
    ) -> Result<[InstalledApplication], InstalledApplicationCatalogFailure> {
        do {
            let applicationURLs = try roots.flatMap {
                try collectApplicationURLs(in: $0, remainingDepth: 3)
            }
            let applications = applicationURLs.compactMap(makeApplication)
            return .success(applications)
        } catch {
            return .failure(.discoveryFailed(error.localizedDescription))
        }
    }

    private static func collectApplicationURLs(
        in directory: URL,
        remainingDepth: Int
    ) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            return []
        }
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return try children.flatMap {
            try collectApplicationURLs(from: $0, remainingDepth: remainingDepth)
        }
    }

    private static func collectApplicationURLs(
        from candidate: URL,
        remainingDepth: Int
    ) throws -> [URL] {
        if candidate.pathExtension.caseInsensitiveCompare("app") == .orderedSame {
            return [candidate]
        }
        guard remainingDepth > 0 else { return [] }
        let values = try candidate.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { return [] }
        return try collectApplicationURLs(in: candidate, remainingDepth: remainingDepth - 1)
    }

    private static func makeApplication(from url: URL) -> InstalledApplication? {
        guard let bundle = Bundle(url: url),
            let bundleIdentifier = bundle.bundleIdentifier
        else {
            return nil
        }
        return InstalledApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: url.deletingPathExtension().lastPathComponent,
            applicationPath: url.standardizedFileURL.path
        )
    }

    @MainActor
    private static func registeredApplications(
        _ applications: [InstalledApplication]
    ) -> [InstalledApplication] {
        applications.map { application in
            let scannedURL = URL(fileURLWithPath: application.applicationPath).standardizedFileURL
            let registeredURL = NSWorkspace.shared
                .urlsForApplications(withBundleIdentifier: application.bundleIdentifier)
                .first { $0.standardizedFileURL == scannedURL }
            return InstalledApplication(
                bundleIdentifier: application.bundleIdentifier,
                displayName: application.displayName,
                applicationPath: (registeredURL ?? scannedURL).path
            )
        }
    }
}
