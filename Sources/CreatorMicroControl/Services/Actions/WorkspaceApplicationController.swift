import AppKit

public enum WorkspaceApplicationFailure: Error, Equatable, Sendable {
    case applicationNotFound(String)
    case activationFailed(String)
}

@MainActor
public final class WorkspaceApplicationController {
    typealias RunningApplicationActivator = @MainActor (String) -> Bool?
    typealias InstalledApplicationLauncher =
        @MainActor (String) async -> Result<
            Void, WorkspaceApplicationFailure
        >

    private let activateRunningApplication: RunningApplicationActivator
    private let launchInstalledApplication: InstalledApplicationLauncher

    public init(workspace: NSWorkspace = .shared) {
        activateRunningApplication = { bundleIdentifier in
            guard
                let application = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleIdentifier
                ).first
            else {
                return nil
            }
            return application.activate(options: [.activateAllWindows])
        }
        launchInstalledApplication = { bundleIdentifier in
            guard
                let applicationURL = workspace.urlForApplication(
                    withBundleIdentifier: bundleIdentifier
                )
            else {
                return .failure(.applicationNotFound(bundleIdentifier))
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            do {
                _ = try await workspace.openApplication(
                    at: applicationURL,
                    configuration: configuration
                )
                return .success(())
            } catch {
                return .failure(
                    .activationFailed("\(bundleIdentifier): \(error.localizedDescription)")
                )
            }
        }
    }

    init(
        activateRunningApplication: @escaping RunningApplicationActivator,
        launchInstalledApplication: @escaping InstalledApplicationLauncher
    ) {
        self.activateRunningApplication = activateRunningApplication
        self.launchInstalledApplication = launchInstalledApplication
    }

    public func activateTerminal() async -> Result<Void, WorkspaceApplicationFailure> {
        await activateApplication(bundleIdentifier: "com.apple.Terminal")
    }

    public func activateFinder() async -> Result<Void, WorkspaceApplicationFailure> {
        await activateApplication(bundleIdentifier: "com.apple.finder")
    }

    public func activateFirstAvailableApplication(
        bundleIdentifiers: [String]
    ) async -> Result<Void, WorkspaceApplicationFailure> {
        guard let firstIdentifier = bundleIdentifiers.first else {
            return .failure(.applicationNotFound(""))
        }
        var lastFailure = WorkspaceApplicationFailure.applicationNotFound(firstIdentifier)
        for bundleIdentifier in bundleIdentifiers {
            switch await activateApplication(bundleIdentifier: bundleIdentifier) {
            case .success:
                return .success(())
            case .failure(let failure):
                lastFailure = failure
            }
        }
        return .failure(lastFailure)
    }

    public func activateApplication(
        bundleIdentifier: String
    ) async -> Result<Void, WorkspaceApplicationFailure> {
        if activateRunningApplication(bundleIdentifier) == true { return .success(()) }
        return await launchInstalledApplication(bundleIdentifier)
    }
}
