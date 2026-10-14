import XCTest

@testable import CreatorMicroCore

final class LightingPriorityResolverTests: XCTestCase {
    private let failure = LightingKeyAppearance(color: .red, brightness: 1, effect: .solid, speed: 0)
    private let observed = LightingKeyAppearance(
        color: RGBColor(red: 1, green: 2, blue: 3), brightness: 0.9, effect: .shallowBreath, speed: 0.3)
    private let agentStatus = LightingKeyAppearance(
        color: RGBColor(red: 4, green: 5, blue: 6), brightness: 0.6, effect: .breath, speed: 0.5)

    func testFailureAlwaysWinsOverEveryOtherTier() {
        let resolved = LightingPriorityResolver.resolve(
            failure: failure, observedSignal: observed, agentStatus: agentStatus,
            category: .volume, isPressed: false)
        XCTAssertEqual(resolved, failure)
    }

    func testObservedSignalWinsOverAgentStatusAndCategory() {
        let resolved = LightingPriorityResolver.resolve(
            failure: nil, observedSignal: observed, agentStatus: agentStatus,
            category: .volume, isPressed: false)
        XCTAssertEqual(resolved, observed)
    }

    func testAgentStatusWinsOverCategoryWhenNoFailureOrObservedSignal() {
        let resolved = LightingPriorityResolver.resolve(
            failure: nil, observedSignal: nil, agentStatus: agentStatus,
            category: .volume, isPressed: false)
        XCTAssertEqual(resolved, agentStatus)
    }

    func testCategoryIsTheRestingFallbackAtIdleBrightness() {
        let resolved = LightingPriorityResolver.resolve(
            failure: nil, observedSignal: nil, agentStatus: nil,
            category: .scripts, isPressed: false)
        XCTAssertEqual(
            resolved,
            LightingKeyAppearance(
                color: SemanticLightingPalette.scripts,
                brightness: SemanticLightingPalette.idleBrightness,
                effect: .solid, speed: 0))
    }

    func testPressLiftsCategoryBrightnessToPressBrightness() {
        let resolved = LightingPriorityResolver.resolve(
            failure: nil, observedSignal: nil, agentStatus: nil,
            category: .scripts, isPressed: true)
        XCTAssertEqual(resolved?.brightness, SemanticLightingPalette.pressBrightness)
    }

    func testPressLiftsObservedStateWithoutChangingItsMeaning() {
        let resolved = LightingPriorityResolver.resolve(
            failure: nil, observedSignal: observed, agentStatus: nil,
            category: .audio, isPressed: true)
        XCTAssertEqual(resolved?.color, observed.color)
        XCTAssertEqual(resolved?.brightness, 1)
    }

    func testUnassignedKeyWithNoCategoryAndNoSignalIsOff() {
        let resolved = LightingPriorityResolver.resolve(
            failure: nil, observedSignal: nil, agentStatus: nil,
            category: nil, isPressed: false)
        XCTAssertNil(resolved)
    }
}
