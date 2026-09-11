import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class SystemAudioUpdatePolicyTests: XCTestCase {
    func testDevicePropertyChangePublishesWithoutRebindingListeners() {
        XCTAssertEqual(
            SystemAudioMonitorUpdatePlanner().operations(for: .deviceProperty),
            [.publishSnapshot]
        )
    }

    func testDefaultDeviceChangeRebindsBeforePublishing() {
        XCTAssertEqual(
            SystemAudioMonitorUpdatePlanner().operations(for: .defaultDevice),
            [.rebindDeviceListeners, .publishSnapshot]
        )
    }

    func testVolumeChangesDoNotRefreshDeviceLighting() {
        let previous = snapshot(input: .unmuted, output: .unmuted, volume: 0.4)
        let volumeChange = snapshot(input: .unmuted, output: .unmuted, volume: 0.5)

        XCTAssertFalse(SystemAudioSnapshotUpdatePolicy.requiresLighting(previous, volumeChange))
    }

    func testInputOrOutputMuteChangeRefreshesDeviceLighting() {
        let previous = snapshot(input: .unmuted, output: .unmuted, volume: 0.4)
        let inputMuted = snapshot(input: .muted, output: .unmuted, volume: 0.4)
        let outputMuted = snapshot(input: .unmuted, output: .muted, volume: 0.4)

        XCTAssertTrue(SystemAudioSnapshotUpdatePolicy.requiresLighting(previous, inputMuted))
        XCTAssertTrue(SystemAudioSnapshotUpdatePolicy.requiresLighting(previous, outputMuted))
    }

    private func snapshot(
        input: AudioMuteState,
        output: AudioMuteState,
        volume: Double
    ) -> SystemAudioSnapshot {
        SystemAudioSnapshot(inputMute: input, outputMute: output, outputVolume: volume)
    }
}
