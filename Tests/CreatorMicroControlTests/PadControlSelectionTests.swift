import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class PadControlSelectionTests: XCTestCase {
    func testDialExposesBothRotationsAndPressForEditing() {
        XCTAssertEqual(
            DialControlSelection.editableControls,
            [.encoderCounterClockwise, .encoderPress, .encoderClockwise]
        )
    }
}
