import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class JoystickModePresentationTests: XCTestCase {
    func testEveryModeHasAnExplicitNameIconAndExplanation() {
        XCTAssertEqual(
            JoystickModePresentation(.arrowKeys),
            .init(
                title: "Arrow Keys",
                symbol: "arrow.up.and.down.and.arrow.left.and.right",
                detail: "Holds the matching arrow key while the stick is deflected."
            )
        )
        XCTAssertEqual(
            JoystickModePresentation(.pointer),
            .init(
                title: "Mouse Pointer",
                symbol: "cursorarrow.motionlines",
                detail: "Moves the macOS pointer with fine control near the centre."
            )
        )
        XCTAssertEqual(
            JoystickModePresentation(.off),
            .init(
                title: "Off",
                symbol: "power",
                detail: "Ignores joystick movement on this layer."
            )
        )
    }

    func testCollapsedSummaryDistinguishesOverrideFromInheritance() {
        XCTAssertEqual(
            JoystickSectionPresentation.summary(for: nil),
            "Inherited · Mouse Pointer"
        )
        XCTAssertEqual(
            JoystickSectionPresentation.summary(
                for: LayerJoystickConfiguration(mode: .arrowKeys)
            ),
            "This layer · Arrow Keys"
        )
    }
}
