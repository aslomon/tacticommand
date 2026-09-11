public enum MicroConfigurationMigrator {
    public static func migrate(
        _ configuration: MicroConfiguration
    ) throws -> MicroConfiguration {
        switch configuration.schemaVersion {
        case MicroConfiguration.currentSchemaVersion:
            return configuration
        case 7:
            return migrateVersionSeven(configuration)
        case 6:
            return migrateVersionSeven(migrateVersionSix(configuration))
        case 5:
            return migrateVersionSeven(migrateVersionFive(configuration))
        case 4:
            return migrateVersionSeven(migrateVersionFive(migrateVersionFour(configuration)))
        case 3:
            return migrateVersionSeven(
                migrateVersionFive(migrateVersionFour(migrateVersionThree(configuration)))
            )
        case 2:
            return migrateVersionSeven(
                migrateVersionFive(
                    migrateVersionFour(migrateVersionThree(migrateVersionTwo(configuration)))
                )
            )
        case 1:
            return migrateVersionSeven(
                migrateVersionFive(
                    migrateVersionFour(
                        migrateVersionThree(
                            migrateVersionTwo(migrateVersionOne(configuration))
                        )
                    )
                )
            )
        default:
            throw MicroConfigurationValidationFailure(
                message: "Unsupported schema version \(configuration.schemaVersion)."
            )
        }
    }
}
