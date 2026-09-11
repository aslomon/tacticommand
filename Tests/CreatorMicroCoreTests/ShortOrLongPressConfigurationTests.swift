import XCTest

@testable import CreatorMicroCore

final class ShortOrLongPressConfigurationTests: XCTestCase {
    func testRegularPressControlAcceptsDualBinding() throws {
        let configuration = configuration(
            control: .action6,
            action: dual(short: .openFinder, long: .openTerminal)
        )

        XCTAssertNoThrow(try MicroConfigurationValidator.validate(configuration))
    }

    func testEncoderRotationsRejectDualBinding() {
        for control in [ControlID.encoderClockwise, .encoderCounterClockwise] {
            let configuration = configuration(
                control: control,
                action: dual(short: .volume(.increase), long: .outputMute(.toggle))
            )

            XCTAssertThrowsError(try MicroConfigurationValidator.validate(configuration))
        }
    }

    func testNestedAndUnassignedBranchesAreRejected() {
        let valid = dual(short: .openFinder, long: .openTerminal)
        let invalidActions = [
            dual(short: valid, long: .returnKey),
            dual(short: .returnKey, long: valid),
            dual(short: .none, long: .returnKey),
            dual(short: .returnKey, long: .none),
        ]

        for action in invalidActions {
            let configuration = configuration(control: .action6, action: action)
            XCTAssertThrowsError(try MicroConfigurationValidator.validate(configuration))
        }
    }

    private func dual(
        short: CreatorAction,
        long: CreatorAction
    ) -> CreatorAction {
        .shortOrLongPress(shortPress: short, longPress: long)
    }

    private func configuration(
        control: ControlID,
        action: CreatorAction
    ) -> MicroConfiguration {
        var configuration = MicroConfiguration.default
        configuration.assign(action: action, to: control, on: .desktop)
        return configuration
    }
}
