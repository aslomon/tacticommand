import Foundation
import XCTest

@testable import CreatorMicroCore

final class AppConfigurationTests: XCTestCase {
    func testDefaultConfigurationContainsSixNamedLayers() {
        let configuration = MicroConfiguration.default

        XCTAssertEqual(configuration.layers.count, 6)
        XCTAssertEqual(
            configuration.layers.map(\.name),
            ["Codex", "Desktop", "Agents", "Windows", "Meetings", "Snippets"]
        )
        XCTAssertEqual(configuration.microphoneLayout, .separate)
    }

    func testDesktopLayerProvidesTheRequestedCoreControls() throws {
        let configuration = MicroConfiguration.default
        let desktop = try XCTUnwrap(configuration.layer(.desktop))

        XCTAssertEqual(desktop.action(for: .action6), .openTerminal)
        XCTAssertEqual(desktop.action(for: .action7), .openFinder)
        XCTAssertEqual(desktop.action(for: .action8), .inputMute(.toggle))
        XCTAssertEqual(desktop.action(for: .action9), .layer(.next))
        XCTAssertEqual(
            desktop.action(for: .action10),
            .dictation(DictationBinding(providerID: .rede, behavior: .toggle))
        )
        XCTAssertEqual(desktop.action(for: .action11), .approval)
        XCTAssertEqual(desktop.action(for: .action12), .returnKey)
        XCTAssertEqual(desktop.action(for: .encoderClockwise), .volume(.increase))
        XCTAssertEqual(desktop.action(for: .encoderCounterClockwise), .volume(.decrease))
        XCTAssertEqual(desktop.action(for: .encoderPress), .outputMute(.toggle))
        XCTAssertEqual(desktop.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(desktop.action(for: .agent2), .escapeKey)
        XCTAssertEqual(desktop.action(for: .agent5), .deleteKey)
        XCTAssertEqual(desktop.action(for: .agent0), .none)
    }

    func testEveryDefaultLayerProvidesDedicatedAudioControls() {
        for layer in MicroConfiguration.default.layers {
            XCTAssertEqual(layer.action(for: .action8), .inputMute(.toggle))
            XCTAssertEqual(layer.action(for: .encoderClockwise), .volume(.increase))
            XCTAssertEqual(layer.action(for: .encoderCounterClockwise), .volume(.decrease))
            XCTAssertEqual(layer.action(for: .encoderPress), .outputMute(.toggle))
        }
    }

    func testAgentLayerMapsSixLightsToSixFocusSlots() throws {
        let agents = try XCTUnwrap(MicroConfiguration.default.layer(.agents))

        for (index, control) in agentControls.enumerated() {
            XCTAssertEqual(
                agents.action(for: control),
                .agentFocus(sessionID: "slot-\(index + 1)")
            )
        }
        XCTAssertEqual(agents.action(for: .action6), .openTerminal)
        XCTAssertEqual(agents.action(for: .action9), .layer(.next))
        XCTAssertEqual(agents.action(for: .action12), .returnKey)
    }

    func testWindowsLayerProvidesBidirectionalNavigationAndClicks() throws {
        let windows = try XCTUnwrap(MicroConfiguration.default.layer(.windows))

        XCTAssertEqual(windows.action(for: .agent0), .switchApplication(.next))
        XCTAssertEqual(windows.action(for: .agent1), .pointer(.click(.primary)))
        XCTAssertEqual(windows.action(for: .agent2), .switchWindow(.next))
        XCTAssertEqual(windows.action(for: .agent3), .switchWindow(.previous))
        XCTAssertEqual(windows.action(for: .agent4), .switchApplication(.previous))
        XCTAssertEqual(windows.action(for: .agent5), .none)
    }

    func testSecondaryAndMiddleClicksRemainAssignableButAreNotDefaults() {
        let configuredActions = MicroConfiguration.default.layers.flatMap {
            $0.bindings.values
        }

        XCTAssertFalse(configuredActions.contains(.pointer(.click(.secondary))))
        XCTAssertFalse(configuredActions.contains(.pointer(.click(.middle))))
    }

    func testEveryDefaultLayerCanAdvanceFromThePhysicalActionNineKey() {
        for layer in MicroConfiguration.default.layers {
            XCTAssertEqual(layer.action(for: .action9), .layer(.next))
        }
    }

    func testSnippetsLayerHasSixImmediatelyEditableTextSlots() throws {
        let snippets = try XCTUnwrap(MicroConfiguration.default.layer(.snippets))

        for control in agentControls {
            guard case .textSnippet(let text) = snippets.action(for: control) else {
                return XCTFail("Expected a text snippet for \(control)")
            }
            XCTAssertFalse(text.isEmpty)
        }
    }

    func testConfigurationRoundTripsThroughJSON() throws {
        var configuration = MicroConfiguration.default
        configuration.assign(
            action: .textSnippet("Ship it"),
            to: .agent5,
            on: .snippets
        )

        let data = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(MicroConfiguration.self, from: data)

        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(
            decoded.layer(.snippets)?.action(for: .agent5),
            .textSnippet("Ship it")
        )
    }

    func testValidatorRejectsShortcutsBeyondTheSafeChordLimit() {
        var configuration = MicroConfiguration.default
        let keys = (0...KeyShortcut.maximumMainKeyCount).map { index in
            KeyShortcutKey(key: "key-\(index)")
        }
        configuration.assign(
            action: .dictation(
                DictationBinding(
                    providerID: .rede,
                    behavior: .toggle,
                    shortcut: KeyShortcut(mainKeys: keys)
                )
            ),
            to: .action10,
            on: .desktop
        )

        XCTAssertThrowsError(try MicroConfigurationValidator.validate(configuration))
    }

    func testValidatorAcceptsModifierOnlyShortcutAndRejectsEmptyShortcut() {
        var modifierOnly = MicroConfiguration.default
        modifierOnly.assign(
            action: .dictation(
                DictationBinding(
                    providerID: .rede,
                    behavior: .toggle,
                    shortcut: KeyShortcut(
                        mainKeys: [],
                        modifiers: [.control, .shift]
                    )
                )
            ),
            to: .action10,
            on: .desktop
        )
        XCTAssertNoThrow(try MicroConfigurationValidator.validate(modifierOnly))

        var empty = MicroConfiguration.default
        empty.assign(
            action: .dictation(
                DictationBinding(
                    providerID: .rede,
                    behavior: .toggle,
                    shortcut: KeyShortcut(mainKeys: [], modifiers: [])
                )
            ),
            to: .action10,
            on: .desktop
        )
        XCTAssertThrowsError(try MicroConfigurationValidator.validate(empty))
    }

    func testJoystickModeAndResponseCanBeConfiguredPerLayer() throws {
        var configuration = MicroConfiguration.default
        let meetings = LayerJoystickConfiguration(
            mode: .off,
            deadZone: 0.3,
            maximumSpeed: 700
        )
        configuration.setJoystick(meetings, on: .meetings)

        XCTAssertEqual(configuration.resolvedJoystick(for: .meetings), meetings)
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

    private var agentControls: [ControlID] {
        [.agent0, .agent1, .agent2, .agent3, .agent4, .agent5]
    }
}
