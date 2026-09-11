import Foundation

public enum ConfigurationStoreError: Error, LocalizedError, Equatable, Sendable {
    case read(String)
    case write(String)
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .read(let details):
            return "The Creator Micro configuration could not be read: \(details)"
        case .write(let details):
            return "The Creator Micro configuration could not be saved: \(details)"
        case .invalid(let details):
            return "The Creator Micro configuration is invalid: \(details)"
        }
    }
}

public actor ConfigurationStore {
    public static var defaultFileURL: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("CreatorMicroControl", isDirectory: true)
        .appendingPathComponent("configuration.json")
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var latestGeneration: UInt64 = 0
    private var latestGenerationResult: Result<Void, ConfigurationStoreError> = .success(())

    public init(fileURL: URL = ConfigurationStore.defaultFileURL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public func load() -> Result<MicroConfiguration, ConfigurationStoreError> {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .success(.default)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            guard data.count <= MicroConfigurationValidator.maximumFileBytes else {
                return .failure(.invalid("The file exceeds the size limit."))
            }
            let decoded = try decoder.decode(MicroConfiguration.self, from: data)
            let configuration = try MicroConfigurationMigrator.migrate(decoded)
            try MicroConfigurationValidator.validate(configuration)
            if configuration != decoded {
                if case .failure(let error) = saveValidated(configuration) {
                    return .failure(error)
                }
            }
            return .success(configuration)
        } catch let failure as MicroConfigurationValidationFailure {
            return .failure(.invalid(failure.message))
        } catch {
            return .failure(.read(error.localizedDescription))
        }
    }

    public func save(
        _ configuration: MicroConfiguration
    ) -> Result<Void, ConfigurationStoreError> {
        saveValidated(configuration)
    }

    public func save(
        _ configuration: MicroConfiguration,
        generation: UInt64
    ) -> Result<Void, ConfigurationStoreError> {
        guard generation > latestGeneration else { return latestGenerationResult }
        latestGeneration = generation
        latestGenerationResult = saveValidated(configuration)
        return latestGenerationResult
    }

    private func saveValidated(
        _ configuration: MicroConfiguration
    ) -> Result<Void, ConfigurationStoreError> {
        do {
            try MicroConfigurationValidator.validate(configuration)
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try encoder.encode(configuration)
            guard data.count <= MicroConfigurationValidator.maximumFileBytes else {
                return .failure(.invalid("The encoded file exceeds the size limit."))
            }
            try data.write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
            return .success(())
        } catch let failure as MicroConfigurationValidationFailure {
            return .failure(.invalid(failure.message))
        } catch {
            return .failure(.write(error.localizedDescription))
        }
    }
}
