import XCTest

@testable import CreatorMicroCore

final class DictationProviderRegistryTests: XCTestCase {
    func testRegistryAlwaysListsThreeBuiltInProvidersFirst() async throws {
        let registry = DictationProviderRegistry(catalog: StaticApplicationCatalog(applications: []))

        let providers = try await registry.providers().get()

        XCTAssertEqual(
            providers.map(\.id),
            [.rede, .chatGPTCodex, .appleDictation]
        )
        XCTAssertEqual(
            providers.map(\.source),
            [
                .builtIn(.rede),
                .builtIn(.chatGPTCodex),
                .builtIn(.appleDictation),
            ]
        )
    }

    func testRegistryAddsInstalledApplicationsInDisplayNameOrder() async throws {
        let catalog = StaticApplicationCatalog(
            applications: [
                InstalledApplication(
                    bundleIdentifier: "com.example.superwhisper",
                    displayName: "Superwhisper",
                    applicationPath: "/Applications/Superwhisper.app"
                ),
                InstalledApplication(
                    bundleIdentifier: "com.example.audiotype",
                    displayName: "AudioType",
                    applicationPath: "/Applications/AudioType.app"
                ),
            ]
        )
        let registry = DictationProviderRegistry(catalog: catalog)

        let providers = try await registry.providers().get()

        XCTAssertEqual(
            providers.map(\.id),
            [
                .rede,
                .chatGPTCodex,
                .appleDictation,
                DictationProviderID(applicationBundleIdentifier: "com.example.audiotype"),
                DictationProviderID(applicationBundleIdentifier: "com.example.superwhisper"),
            ]
        )
    }

    func testRegistryDoesNotDuplicateApplicationsRepresentedByBuiltIns() async throws {
        let catalog = StaticApplicationCatalog(
            applications: [
                InstalledApplication(
                    bundleIdentifier: "app.rede.mac",
                    displayName: "rede",
                    applicationPath: "/Applications/rede.app"
                ),
                InstalledApplication(
                    bundleIdentifier: "com.openai.codex",
                    displayName: "ChatGPT",
                    applicationPath: "/Applications/ChatGPT.app"
                ),
                InstalledApplication(
                    bundleIdentifier: "com.example.voice",
                    displayName: "Voice",
                    applicationPath: "/Applications/Voice.app"
                ),
            ]
        )
        let registry = DictationProviderRegistry(catalog: catalog)

        let providers = try await registry.providers().get()

        XCTAssertEqual(providers.count, 4)
        XCTAssertEqual(providers[0].availability, .available)
        XCTAssertEqual(providers[1].availability, .available)
        XCTAssertEqual(providers[3].source, .installedApplication)
    }

    func testRefreshingRegistryObservesNewlyInstalledApplications() async throws {
        let initialApplication = InstalledApplication(
            bundleIdentifier: "com.example.voice",
            displayName: "Voice",
            applicationPath: "/Applications/Voice.app"
        )
        let addedApplication = InstalledApplication(
            bundleIdentifier: "com.example.words",
            displayName: "Words",
            applicationPath: "/Applications/Words.app"
        )
        let catalog = MutableApplicationCatalog(applications: [initialApplication])
        let registry = DictationProviderRegistry(catalog: catalog)

        let initialProviders = try await registry.providers().get()
        await catalog.replaceApplications(with: [initialApplication, addedApplication])
        let refreshedProviders = try await registry.providers().get()

        XCTAssertEqual(initialProviders.count, 4)
        XCTAssertEqual(refreshedProviders.count, 5)
        XCTAssertEqual(
            refreshedProviders.last?.id,
            DictationProviderID(applicationBundleIdentifier: "com.example.words")
        )
    }

    func testRegistryReturnsCatalogFailureWithoutInventingProviders() async {
        let expectedFailure = InstalledApplicationCatalogFailure.discoveryFailed("Spotlight unavailable")
        let registry = DictationProviderRegistry(
            catalog: StaticApplicationCatalog(result: .failure(expectedFailure))
        )

        let result = await registry.providers()

        XCTAssertEqual(result, .failure(expectedFailure))
    }
}

private struct StaticApplicationCatalog: InstalledApplicationCatalog {
    private let result: Result<[InstalledApplication], InstalledApplicationCatalogFailure>

    init(applications: [InstalledApplication]) {
        result = .success(applications)
    }

    init(result: Result<[InstalledApplication], InstalledApplicationCatalogFailure>) {
        self.result = result
    }

    func installedApplications() async -> Result<[InstalledApplication], InstalledApplicationCatalogFailure> {
        result
    }
}

private actor MutableApplicationCatalog: InstalledApplicationCatalog {
    private var applications: [InstalledApplication]

    init(applications: [InstalledApplication]) {
        self.applications = applications
    }

    func replaceApplications(with applications: [InstalledApplication]) {
        self.applications = applications
    }

    func installedApplications() -> Result<[InstalledApplication], InstalledApplicationCatalogFailure> {
        .success(applications)
    }
}
