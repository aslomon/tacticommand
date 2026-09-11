import CreatorMicroCore
import XCTest

@testable import CreatorMicroControl

final class KeyActionLiveStateTests: XCTestCase {
    func testInputMuteShowsTheActualMicrophoneStateForEveryMuteCommand() {
        for command in [MuteCommand.toggle, .mute, .unmute] {
            XCTAssertEqual(
                KeyActionLiveState.resolve(
                    action: .inputMute(command),
                    audio: snapshot(input: .muted),
                    isDictating: false
                ),
                KeyActionLiveState(
                    label: "Mic muted",
                    compactLabel: "MUTED",
                    symbol: "mic.slash.fill",
                    tone: .failure
                )
            )
        }
    }

    func testMuteActionsShowPositiveMixedAndUnavailableStates() {
        XCTAssertEqual(
            state(for: .inputMute(.toggle), input: .unmuted),
            .init(label: "Mic on", compactLabel: "ON", symbol: "mic.fill", tone: .ready)
        )
        XCTAssertEqual(
            state(for: .outputMute(.toggle), output: .mixed),
            .init(
                label: "Output mixed",
                compactLabel: "MIXED",
                symbol: "speaker.badge.exclamationmark",
                tone: .attention
            )
        )
        XCTAssertEqual(
            state(for: .outputMute(.toggle), output: .unavailable),
            .init(
                label: "Output unknown",
                compactLabel: "UNKNOWN",
                symbol: "speaker.badge.questionmark",
                tone: .unavailable
            )
        )
    }

    func testDictationAndVolumeExposeUsefulLiveState() {
        XCTAssertNil(state(for: dictationAction, isDictating: false))
        XCTAssertEqual(
            state(for: dictationAction, isDictating: true),
            .init(
                label: "Dictation toggle active",
                compactLabel: "ACTIVE",
                symbol: "waveform",
                tone: .recording
            )
        )
        XCTAssertEqual(
            state(for: .volume(.increase), volume: 0.42),
            .init(
                label: "Output volume 42 percent",
                compactLabel: "42%",
                symbol: "speaker.wave.2.fill",
                tone: .signal
            )
        )
    }

    func testActionSequenceExposesItsStrongestLiveState() {
        XCTAssertEqual(
            state(
                for: .actionSequence([.copy, .inputMute(.toggle)]),
                input: .muted
            )?.tone,
            .failure
        )
    }

    func testDualActionPrefersTheMostImportantCurrentState() {
        let action = CreatorAction.shortOrLongPress(
            shortPress: .inputMute(.toggle),
            longPress: .outputMute(.toggle)
        )

        XCTAssertEqual(
            state(for: action, input: .muted, output: .mixed)?.tone,
            .failure
        )
    }

    func testSemanticStateMapsToPhysicalAgentKeyLighting() throws {
        let muted = try XCTUnwrap(
            state(for: .inputMute(.toggle), input: .muted)?.agentKeyLighting(index: 2)
        )
        let active = try XCTUnwrap(
            state(for: dictationAction, isDictating: true)?.agentKeyLighting(index: 3)
        )

        XCTAssertEqual(muted.color, .red)
        XCTAssertEqual(muted.effect, .solid)
        XCTAssertEqual(active.color, RGBColor(red: 34, green: 211, blue: 167))
        XCTAssertEqual(active.effect, .shallowBreath)
    }

    private var dictationAction: CreatorAction {
        .dictation(DictationBinding(providerID: .chatGPTCodex, behavior: .toggle))
    }

    private func state(
        for action: CreatorAction,
        input: AudioMuteState = .unmuted,
        output: AudioMuteState = .unmuted,
        volume: Double? = nil,
        isDictating: Bool = false
    ) -> KeyActionLiveState? {
        KeyActionLiveState.resolve(
            action: action,
            audio: SystemAudioSnapshot(
                inputMute: input,
                outputMute: output,
                outputVolume: volume
            ),
            isDictating: isDictating
        )
    }

    private func snapshot(input: AudioMuteState) -> SystemAudioSnapshot {
        SystemAudioSnapshot(
            inputMute: input,
            outputMute: .unmuted,
            outputVolume: nil
        )
    }
}
