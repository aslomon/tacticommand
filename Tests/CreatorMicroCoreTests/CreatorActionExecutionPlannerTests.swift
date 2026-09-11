import XCTest

@testable import CreatorMicroCore

final class CreatorActionExecutionPlannerTests: XCTestCase {
    func testRegularActionRunsOnceOnPressAndIgnoresRelease() {
        let planner = CreatorActionExecutionPlanner()

        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .openFinder, phase: .pressed)),
            .performOnce(.openFinder)
        )
        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .openFinder, phase: .released)),
            .ignore
        )
    }

    func testDeleteActionRunsOnceOnPressAndIgnoresRelease() {
        let planner = CreatorActionExecutionPlanner()

        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .deleteKey, phase: .pressed)),
            .performOnce(.deleteKey)
        )
        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .deleteKey, phase: .released)),
            .ignore
        )
    }

    func testToggleDictationRunsOnceOnPress() {
        let binding = DictationBinding(providerID: .chatGPTCodex, behavior: .toggle)
        let planner = CreatorActionExecutionPlanner()

        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .dictation(binding), phase: .pressed)),
            .performOnce(.dictation(binding))
        )
        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .dictation(binding), phase: .released)),
            .ignore
        )
    }

    func testHoldToTalkDictationPreservesBothPhases() {
        let binding = DictationBinding(providerID: .rede, behavior: .holdToTalk)
        let planner = CreatorActionExecutionPlanner()

        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .dictation(binding), phase: .pressed)),
            .beginDictation(binding)
        )
        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .dictation(binding), phase: .released)),
            .endDictation(binding)
        )
    }

    func testUnassignedActionIsAlwaysIgnored() {
        let planner = CreatorActionExecutionPlanner()

        XCTAssertEqual(
            planner.plan(RoutedCreatorAction(action: .none, phase: .pressed)),
            .ignore
        )
    }
}
