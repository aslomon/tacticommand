import XCTest

@testable import CreatorMicroCore

final class SemanticLightingPaletteTests: XCTestCase {
    func testNavigationAndAgentNavigationActionsUseLayerCyan() {
        XCTAssertEqual(FunctionCategory.classify(.layer(.next)), .navigationLayer)
        XCTAssertEqual(FunctionCategory.classify(.focusNextAgent), .navigationLayer)
        XCTAssertEqual(FunctionCategory.classify(.agentFocus(sessionID: "s1")), .navigationLayer)
    }

    func testTextAndEditingActionsUseTextClipboardCategory() {
        let actions: [CreatorAction] = [
            .copy, .paste, .pastePlainText, .textSnippet("hi"), .returnKey, .escapeKey, .deleteKey,
        ]
        for action in actions {
            XCTAssertEqual(FunctionCategory.classify(action), .textClipboard, "\(action)")
        }
    }

    func testWorkspaceActionsUseAppWindowLaunchCategory() {
        let actions: [CreatorAction] = [
            .openTerminal, .openFinder, .openApplication(bundleIdentifier: "x"),
            .switchApplication(.next), .switchWindow(.previous),
        ]
        for action in actions {
            XCTAssertEqual(FunctionCategory.classify(action), .appWindowLaunch, "\(action)")
        }
    }

    func testAudioVolumeRecordingAndScriptCategories() {
        XCTAssertEqual(FunctionCategory.classify(.outputMute(.toggle)), .audio)
        XCTAssertEqual(FunctionCategory.classify(.inputMute(.toggle)), .audio)
        XCTAssertEqual(FunctionCategory.classify(.volume(.increase)), .volume)
        XCTAssertEqual(
            FunctionCategory.classify(.dictation(.init(providerID: .rede, behavior: .toggle))),
            .recording)
        XCTAssertEqual(FunctionCategory.classify(.appleScript("x")), .scripts)
        XCTAssertEqual(FunctionCategory.classify(.shellCommand("x")), .scripts)
    }

    func testUnassignedActionHasNoCategory() {
        XCTAssertNil(FunctionCategory.classify(.none))
    }

    func testShortOrLongPressClassifiesByShortPress() {
        let action = CreatorAction.shortOrLongPress(shortPress: .copy, longPress: .appleScript("x"))
        XCTAssertEqual(FunctionCategory.classify(action), .textClipboard)
    }

    func testActionSequenceClassifiesByFirstNonNoneAction() {
        let action = CreatorAction.actionSequence([.none, .volume(.increase), .copy])
        XCTAssertEqual(FunctionCategory.classify(action), .volume)
    }

    func testPaletteColorsMatchApprovedHexValues() {
        XCTAssertEqual(
            SemanticLightingPalette.color(for: .navigationLayer),
            RGBColor(red: 0x24, green: 0xC8, blue: 0xDB))
        XCTAssertEqual(
            SemanticLightingPalette.color(for: .appWindowLaunch),
            RGBColor(red: 0x34, green: 0x78, blue: 0xF6))
        XCTAssertEqual(
            SemanticLightingPalette.color(for: .volume),
            RGBColor(red: 0x24, green: 0xC8, blue: 0xDB))
        XCTAssertEqual(
            SemanticLightingPalette.color(for: .recording),
            RGBColor(red: 0x22, green: 0xD3, blue: 0xA7))
        XCTAssertEqual(
            SemanticLightingPalette.color(for: .scripts),
            RGBColor(red: 0xFF, green: 0x9F, blue: 0x0A))
        XCTAssertEqual(
            SemanticLightingPalette.audioObserved(.muted), RGBColor(red: 0xFF, green: 0x45, blue: 0x3A))
        XCTAssertEqual(
            SemanticLightingPalette.audioObserved(.mixed), RGBColor(red: 0xFF, green: 0x9F, blue: 0x0A))
        XCTAssertEqual(
            SemanticLightingPalette.audioObserved(.unmuted), RGBColor(red: 0x30, green: 0xD1, blue: 0x58))
    }

    func testBrightnessLevelsFollowApprovedRange() {
        XCTAssertEqual(SemanticLightingPalette.idleBrightness, 0.325, accuracy: 0.001)
        XCTAssertTrue((0.30...0.35).contains(SemanticLightingPalette.idleBrightness))
        XCTAssertEqual(SemanticLightingPalette.activeBrightness, 0.85)
        XCTAssertEqual(SemanticLightingPalette.pressBrightness, 1.0)
    }
}
