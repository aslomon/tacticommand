import Foundation
import XCTest

@testable import CreatorMicroCore

extension AppConfigurationTests {
    func testJoystickModeAndResponseCanBeConfiguredPerLayer() throws {
        var configuration = MicroConfiguration.default
        let meetings = LayerJoystickConfiguration(
            mode: .off,
            deadZone: 0.3,
            maximumSpeed: 700
        )
        configuration.setJoystick(meetings, on: .meetingControls)

        XCTAssertEqual(configuration.resolvedJoystick(for: .meetingControls), meetings)
        let desktop = try XCTUnwrap(configuration.resolvedJoystick(for: .desktop))
        XCTAssertEqual(desktop.mode, .arrowKeys)

        configuration.setJoystick(
            LayerJoystickConfiguration(
                mode: .pointer,
                deadZone: 0.2,
                maximumSpeed: 900
            ),
            on: .windows
        )
        XCTAssertEqual(
            configuration.resolvedJoystick(for: .windows),
            LayerJoystickConfiguration(
                mode: .pointer,
                deadZone: 0.2,
                maximumSpeed: 900
            )
        )
    }

    func testLayerWithoutOverrideInheritsGlobalPointerConfiguration() throws {
        var configuration = MicroConfiguration.default
        configuration.setJoystick(nil, on: .codex)
        configuration.joystick = JoystickConfiguration(deadZone: 0.24, maximumSpeed: 820)

        let resolved = try XCTUnwrap(configuration.resolvedJoystick(for: .codex))

        XCTAssertEqual(resolved.mode, .pointer)
        XCTAssertEqual(resolved.deadZone, 0.24)
        XCTAssertEqual(resolved.maximumSpeed, 820)
    }

    func testLegacyLayerJoystickBooleanDecodesToPointerOrOff() throws {
        let enabled = try JSONDecoder().decode(
            LayerJoystickConfiguration.self,
            from: Data(#"{"isEnabled":true,"deadZone":0.2,"maximumSpeed":900}"#.utf8)
        )
        let disabled = try JSONDecoder().decode(
            LayerJoystickConfiguration.self,
            from: Data(#"{"isEnabled":false,"deadZone":0.3,"maximumSpeed":700}"#.utf8)
        )

        XCTAssertEqual(enabled.mode, .pointer)
        XCTAssertEqual(disabled.mode, .off)
    }

    func testJoystickModeRoundTripsWithoutLegacyBoolean() throws {
        let expected = LayerJoystickConfiguration(
            mode: .arrowKeys,
            deadZone: 0.18,
            maximumSpeed: 1_250
        )

        let data = try JSONEncoder().encode(expected)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let decoded = try JSONDecoder().decode(LayerJoystickConfiguration.self, from: data)

        XCTAssertEqual(decoded, expected)
        XCTAssertEqual(object["mode"] as? String, "arrowKeys")
        XCTAssertNil(object["isEnabled"])
    }

    func testValidatorRejectsDecodedLayerJoystickOutsideAllowedRange() throws {
        let data = Data(
            #"{"mode":"pointer","deadZone":1.2,"maximumSpeed":900}"#.utf8
        )
        let decoded = try JSONDecoder().decode(LayerJoystickConfiguration.self, from: data)
        var configuration = MicroConfiguration.default
        configuration.setJoystick(decoded, on: .desktop)

        XCTAssertThrowsError(try MicroConfigurationValidator.validate(configuration))
    }
}
