import XCTest

@testable import CreatorMicroCore

final class SystemAudioStateTests: XCTestCase {
    func testMuteStateReflectsEveryObservedChannel() {
        XCTAssertEqual(AudioMuteState(channelValues: []), .unavailable)
        XCTAssertEqual(AudioMuteState(channelValues: [false, false]), .unmuted)
        XCTAssertEqual(AudioMuteState(channelValues: [true, true]), .muted)
        XCTAssertEqual(AudioMuteState(channelValues: [true, false]), .mixed)
    }

    func testIncreaseAppliesOneDeltaWithoutFlatteningStereoBalance() {
        let values = AudioVolumePlanner().values(
            after: .increase,
            currentValues: [0.8, 0.4],
            step: 0.1
        )

        XCTAssertEqual(values[0], 0.9, accuracy: 0.000_001)
        XCTAssertEqual(values[1], 0.5, accuracy: 0.000_001)
    }

    func testDecreaseAppliesOneDeltaWithoutFlatteningStereoBalance() {
        let values = AudioVolumePlanner().values(
            after: .decrease,
            currentValues: [0.8, 0.4],
            step: 0.1
        )

        XCTAssertEqual(values[0], 0.7, accuracy: 0.000_001)
        XCTAssertEqual(values[1], 0.3, accuracy: 0.000_001)
    }

    func testSetMovesLoudestChannelToTargetAndPreservesDelta() {
        let values = AudioVolumePlanner().values(
            after: .set(0.6),
            currentValues: [0.8, 0.4],
            step: 0.1
        )

        XCTAssertEqual(values[0], 0.6, accuracy: 0.000_001)
        XCTAssertEqual(values[1], 0.2, accuracy: 0.000_001)
    }

    func testVolumePlannerLimitsSharedDeltaAtDeviceBounds() {
        let values = AudioVolumePlanner().values(
            after: .increase,
            currentValues: [0.98, 0.5],
            step: 0.1
        )

        XCTAssertEqual(values[0], 1.0, accuracy: 0.000_001)
        XCTAssertEqual(values[1], 0.52, accuracy: 0.000_001)
        XCTAssertEqual(values[0] - values[1], 0.48, accuracy: 0.000_001)
    }

    func testVolumePlannerReturnsNoValuesForUnavailableDevice() {
        XCTAssertEqual(
            AudioVolumePlanner().values(
                after: .increase,
                currentValues: [],
                step: 0.1
            ),
            []
        )
    }
}
