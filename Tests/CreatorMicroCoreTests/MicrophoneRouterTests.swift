import XCTest

@testable import CreatorMicroCore

final class MicrophoneRouterTests: XCTestCase {
    func testLinkedMicrophoneEmitsOneLogicalPressAndReleaseForBothSwitches() {
        let action = CreatorAction.dictation(
            DictationBinding(providerID: .rede, behavior: .holdToTalk)
        )
        let bindings = MicrophoneBindings(left: action, right: .approval)
        var router = MicrophoneRouter(layout: .linked)

        XCTAssertEqual(
            router.process(
                MicrophoneInput(switchID: .left, phase: .pressed),
                bindings: bindings
            ),
            [RoutedCreatorAction(action: action, phase: .pressed)]
        )
        XCTAssertEqual(
            router.process(
                MicrophoneInput(switchID: .right, phase: .pressed),
                bindings: bindings
            ),
            []
        )
        XCTAssertEqual(
            router.process(
                MicrophoneInput(switchID: .left, phase: .released),
                bindings: bindings
            ),
            []
        )
        XCTAssertEqual(
            router.process(
                MicrophoneInput(switchID: .right, phase: .released),
                bindings: bindings
            ),
            [RoutedCreatorAction(action: action, phase: .released)]
        )
    }

    func testLinkedMicrophoneWorksWhenOnlyOnePhysicalSwitchReports() {
        let action = CreatorAction.openTerminal
        let bindings = MicrophoneBindings(left: action, right: .approval)
        var router = MicrophoneRouter(layout: .linked)

        let pressed = router.process(
            MicrophoneInput(switchID: .right, phase: .pressed),
            bindings: bindings
        )
        let released = router.process(
            MicrophoneInput(switchID: .right, phase: .released),
            bindings: bindings
        )

        XCTAssertEqual(pressed, [RoutedCreatorAction(action: action, phase: .pressed)])
        XCTAssertEqual(released, [RoutedCreatorAction(action: action, phase: .released)])
    }

    func testRouterIgnoresDuplicateHardwareReports() {
        let bindings = MicrophoneBindings(left: .openFinder, right: .approval)
        var router = MicrophoneRouter(layout: .linked)

        let firstPress = router.process(
            MicrophoneInput(switchID: .left, phase: .pressed),
            bindings: bindings
        )
        let duplicatePress = router.process(
            MicrophoneInput(switchID: .left, phase: .pressed),
            bindings: bindings
        )
        let firstRelease = router.process(
            MicrophoneInput(switchID: .left, phase: .released),
            bindings: bindings
        )
        let duplicateRelease = router.process(
            MicrophoneInput(switchID: .left, phase: .released),
            bindings: bindings
        )

        XCTAssertEqual(firstPress.count, 1)
        XCTAssertTrue(duplicatePress.isEmpty)
        XCTAssertEqual(firstRelease.count, 1)
        XCTAssertTrue(duplicateRelease.isEmpty)
    }

    func testSeparateMicrophoneRoutesLeftAndRightIndependently() {
        let dictation = CreatorAction.dictation(
            DictationBinding(providerID: .appleDictation, behavior: .toggle)
        )
        let bindings = MicrophoneBindings(left: dictation, right: .approval)
        var router = MicrophoneRouter(layout: .separate)

        let left = router.process(
            MicrophoneInput(switchID: .left, phase: .pressed),
            bindings: bindings
        )
        let right = router.process(
            MicrophoneInput(switchID: .right, phase: .pressed),
            bindings: bindings
        )

        XCTAssertEqual(left, [RoutedCreatorAction(action: dictation, phase: .pressed)])
        XCTAssertEqual(right, [RoutedCreatorAction(action: .approval, phase: .pressed)])
    }

    func testResetReleasesEveryActiveLogicalAction() {
        let dictation = CreatorAction.dictation(
            DictationBinding(providerID: .rede, behavior: .holdToTalk)
        )
        let bindings = MicrophoneBindings(left: dictation, right: .approval)
        var router = MicrophoneRouter(layout: .separate)
        _ = router.process(
            MicrophoneInput(switchID: .left, phase: .pressed),
            bindings: bindings
        )
        _ = router.process(
            MicrophoneInput(switchID: .right, phase: .pressed),
            bindings: bindings
        )

        let releases = router.reset()

        XCTAssertEqual(
            releases,
            [
                RoutedCreatorAction(action: dictation, phase: .released),
                RoutedCreatorAction(action: .approval, phase: .released),
            ]
        )
        XCTAssertTrue(router.reset().isEmpty)
    }

    func testReleaseUsesBindingCapturedWhenPressBegan() {
        let initialBindings = MicrophoneBindings(left: .openFinder, right: .approval)
        let changedBindings = MicrophoneBindings(left: .openTerminal, right: .escapeKey)
        var router = MicrophoneRouter(layout: .linked)
        _ = router.process(
            MicrophoneInput(switchID: .left, phase: .pressed),
            bindings: initialBindings
        )

        let release = router.process(
            MicrophoneInput(switchID: .left, phase: .released),
            bindings: changedBindings
        )

        XCTAssertEqual(
            release,
            [RoutedCreatorAction(action: .openFinder, phase: .released)]
        )
    }

    func testStandardLayoutDefaultsLeftToDictationAndRightToApproval() {
        let binding = DictationBinding(providerID: .rede, behavior: .toggle)

        XCTAssertEqual(
            MicrophoneBindings.standard(dictation: binding),
            MicrophoneBindings(left: .dictation(binding), right: .approval)
        )
    }
}
