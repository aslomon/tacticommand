public struct DictationProviderRegistry<Catalog: InstalledApplicationCatalog>: Sendable {
    private let catalog: Catalog

    public init(catalog: Catalog) {
        self.catalog = catalog
    }

    public func providers()
        async -> Result<[DictationProviderDefinition], InstalledApplicationCatalogFailure>
    {
        switch await catalog.installedApplications() {
        case .success(let applications):
            return .success(makeProviders(from: applications))
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func makeProviders(
        from applications: [InstalledApplication]
    ) -> [DictationProviderDefinition] {
        let installedBundleIdentifiers = Set(applications.map(\.bundleIdentifier))
        let builtIns = BuiltInDictationProvider.allCases.map {
            $0.definition(
                availability: availability(
                    for: $0,
                    installedBundleIdentifiers: installedBundleIdentifiers
                )
            )
        }
        return builtIns + customProviders(from: applications)
    }

    private func availability(
        for provider: BuiltInDictationProvider,
        installedBundleIdentifiers: Set<String>
    ) -> DictationProviderAvailability {
        guard !provider.applicationBundleIdentifiers.isEmpty else { return .available }
        let isInstalled = provider.applicationBundleIdentifiers.contains {
            installedBundleIdentifiers.contains($0)
        }
        return isInstalled ? .available : .notInstalled
    }

    private func customProviders(
        from applications: [InstalledApplication]
    ) -> [DictationProviderDefinition] {
        let builtInBundleIdentifiers = Set(
            BuiltInDictationProvider.allCases.flatMap(\.applicationBundleIdentifiers)
        )
        var uniqueApplications: [String: InstalledApplication] = [:]
        for application in applications where !builtInBundleIdentifiers.contains(application.bundleIdentifier) {
            uniqueApplications[application.bundleIdentifier] =
                uniqueApplications[application.bundleIdentifier] ?? application
        }
        return uniqueApplications.values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            .map(makeCustomProvider)
    }

    private func makeCustomProvider(
        from application: InstalledApplication
    ) -> DictationProviderDefinition {
        DictationProviderDefinition(
            id: DictationProviderID(applicationBundleIdentifier: application.bundleIdentifier),
            displayName: application.displayName,
            source: .installedApplication,
            scope: .systemWide,
            availability: .available,
            defaultBehavior: .toggle,
            defaultShortcut: nil,
            applicationBundleIdentifier: application.bundleIdentifier,
            applicationPath: application.applicationPath
        )
    }
}
