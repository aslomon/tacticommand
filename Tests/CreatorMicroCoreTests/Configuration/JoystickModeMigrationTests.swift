import XCTest

@testable import CreatorMicroCore

final class JoystickModeMigrationTests: XCTestCase {
    func testVersionThreeDesktopPointerBecomesArrowKeysAndKeepsCalibration() throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 3
        legacy.setJoystick(
            LayerJoystickConfiguration(
                mode: .pointer,
                deadZone: 0.020_518_391_927_083_334,
                maximumSpeed: 1_550
            ),
            on: .desktop
        )
        legacy.assign(action: .openFinder, to: .agent0, on: .desktop)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)
        let joystick = try XCTUnwrap(migrated.layer(.desktop)?.joystick)

        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
        XCTAssertEqual(joystick.mode, .arrowKeys)
        XCTAssertEqual(joystick.deadZone, 0.020_518_391_927_083_334)
        XCTAssertEqual(joystick.maximumSpeed, 1_550)
        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent0), .openFinder)
    }

    func testVersionThreeDesktopWithoutOverrideGetsArrowKeyDefault() throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 3
        legacy.setJoystick(nil, on: .desktop)
        legacy.joystick = JoystickConfiguration(deadZone: 0.21, maximumSpeed: 830)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)
        let joystick = try XCTUnwrap(migrated.layer(.desktop)?.joystick)

        XCTAssertEqual(joystick.mode, .arrowKeys)
        XCTAssertEqual(joystick.deadZone, 0.21)
        XCTAssertEqual(joystick.maximumSpeed, 830)
    }

    func testVersionThreeDesktopOffRemainsOffAndOtherLayersStayUnchanged() throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 3
        let off = LayerJoystickConfiguration(mode: .off, deadZone: 0.3, maximumSpeed: 700)
        let pointer = LayerJoystickConfiguration(mode: .pointer, deadZone: 0.2, maximumSpeed: 900)
        legacy.setJoystick(off, on: .desktop)
        legacy.setJoystick(pointer, on: .windows)

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.layer(.desktop)?.joystick, off)
        XCTAssertEqual(migrated.layer(.windowManagement)?.joystick, pointer)
    }

    func testVersionTwoRunsGeometryAndJoystickMigrationsInOrder() throws {
        var legacy = MicroConfiguration.default
        legacy.schemaVersion = 2
        legacy.assign(action: .escapeKey, to: .agent5, on: .desktop)
        legacy.setJoystick(
            LayerJoystickConfiguration(mode: .pointer, deadZone: 0.02, maximumSpeed: 1_550),
            on: .desktop
        )

        let migrated = try MicroConfigurationMigrator.migrate(legacy)

        XCTAssertEqual(migrated.layer(.desktop)?.action(for: .agent5), .deleteKey)
        XCTAssertEqual(migrated.layer(.desktop)?.joystick?.mode, .arrowKeys)
        XCTAssertEqual(migrated.schemaVersion, MicroConfiguration.currentSchemaVersion)
    }
}
