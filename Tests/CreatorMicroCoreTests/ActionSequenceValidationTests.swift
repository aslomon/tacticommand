import XCTest

@testable import CreatorMicroCore

final class ActionSequenceValidationTests: XCTestCase {
    func testSafeSequenceIsAccepted() throws {
        let configuration = configured(
            with: .actionSequence([.copy, .pastePlainText, .returnKey])
        )

        XCTAssertNoThrow(try MicroConfigurationValidator.validate(configuration))
    }

    func testScriptsNestedSequencesAndInvalidStepCountsAreRejected() {
        let invalidActions: [CreatorAction] = [
            .actionSequence([.copy]),
            .actionSequence([.copy, .shellCommand("pwd")]),
            .actionSequence([.copy, .actionSequence([.copy, .paste])]),
        ]

        for action in invalidActions {
            XCTAssertThrowsError(
                try MicroConfigurationValidator.validate(configured(with: action))
            )
        }
    }

    private func configured(with action: CreatorAction) -> MicroConfiguration {
        var configuration = MicroConfiguration.default
        configuration.assign(action: action, to: .action6, on: .desktop)
        return configuration
    }
}
