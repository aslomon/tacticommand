import CreatorMicroCore

enum KeyActionStateTone: Int, Equatable {
    case unavailable = 1
    case ready = 2
    case signal = 3
    case attention = 4
    case recording = 5
    case failure = 6
}

struct KeyActionLiveState: Equatable {
    let label: String
    let compactLabel: String
    let symbol: String
    let tone: KeyActionStateTone

    static func resolve(
        action: CreatorAction,
        audio: SystemAudioSnapshot,
        isDictating: Bool
    ) -> KeyActionLiveState? {
        switch action {
        case .inputMute:
            microphoneState(audio.inputMute)
        case .outputMute:
            outputState(audio.outputMute)
        case .dictation where isDictating:
            .init(
                label: "Dictation toggle active",
                compactLabel: "ACTIVE",
                symbol: "waveform",
                tone: .recording
            )
        case .volume where audio.outputVolume != nil:
            volumeState(audio.outputVolume)
        case .shortOrLongPress(let shortPress, let longPress):
            strongest(
                resolve(action: shortPress, audio: audio, isDictating: isDictating),
                resolve(action: longPress, audio: audio, isDictating: isDictating)
            )
        case .actionSequence(let actions):
            actions.compactMap {
                resolve(action: $0, audio: audio, isDictating: isDictating)
            }
            .max { $0.tone.rawValue < $1.tone.rawValue }
        default:
            nil
        }
    }

    func agentKeyLighting(index: Int) throws -> AgentKeyLighting {
        let presentation = devicePresentation
        return try AgentKeyLighting(
            index: index,
            color: presentation.color,
            brightness: presentation.brightness,
            effect: presentation.effect,
            speed: presentation.speed
        )
    }

    var appearance: LightingKeyAppearance {
        let presentation = devicePresentation
        let color: RGBColor =
            switch tone {
            case .failure: SemanticLightingPalette.audioMuted
            case .ready: SemanticLightingPalette.audioUnmuted
            case .recording: SemanticLightingPalette.recording
            case .signal: SemanticLightingPalette.volume
            case .attention, .unavailable: SemanticLightingPalette.scripts
            }
        return LightingKeyAppearance(
            color: color,
            brightness: presentation.brightness,
            effect: presentation.effect,
            speed: presentation.speed
        )
    }

    private static func microphoneState(_ state: AudioMuteState) -> KeyActionLiveState {
        switch state {
        case .muted:
            .init(label: "Mic muted", compactLabel: "MUTED", symbol: "mic.slash.fill", tone: .failure)
        case .unmuted:
            .init(label: "Mic on", compactLabel: "ON", symbol: "mic.fill", tone: .ready)
        case .mixed:
            .init(label: "Mic mixed", compactLabel: "MIXED", symbol: "mic.badge.xmark", tone: .attention)
        case .unavailable:
            .init(label: "Mic unknown", compactLabel: "UNKNOWN", symbol: "mic.badge.questionmark", tone: .unavailable)
        }
    }

    private static func outputState(_ state: AudioMuteState) -> KeyActionLiveState {
        switch state {
        case .muted:
            .init(label: "Output muted", compactLabel: "MUTED", symbol: "speaker.slash.fill", tone: .attention)
        case .unmuted:
            .init(label: "Output on", compactLabel: "ON", symbol: "speaker.wave.2.fill", tone: .ready)
        case .mixed:
            .init(
                label: "Output mixed", compactLabel: "MIXED", symbol: "speaker.badge.exclamationmark", tone: .attention)
        case .unavailable:
            .init(
                label: "Output unknown", compactLabel: "UNKNOWN", symbol: "speaker.badge.questionmark",
                tone: .unavailable)
        }
    }

    private static func volumeState(_ volume: Double?) -> KeyActionLiveState? {
        guard let volume else { return nil }
        let percentage = Int((min(max(volume, 0), 1) * 100).rounded())
        return .init(
            label: "Output volume \(percentage) percent",
            compactLabel: "\(percentage)%",
            symbol: "speaker.wave.2.fill",
            tone: .signal
        )
    }

    private static func strongest(
        _ first: KeyActionLiveState?,
        _ second: KeyActionLiveState?
    ) -> KeyActionLiveState? {
        [first, second]
            .compactMap { $0 }
            .max { $0.tone.rawValue < $1.tone.rawValue }
    }

    private var devicePresentation:
        (
            color: RGBColor,
            brightness: Double,
            effect: LightingEffect,
            speed: Double
        )
    {
        switch tone {
        case .failure: (.red, 1, .solid, 0)
        case .recording: (RGBColor(red: 34, green: 211, blue: 167), 0.9, .shallowBreath, 0.3)
        case .attention: (RGBColor(red: 255, green: 159, blue: 10), 0.8, .solid, 0)
        case .signal: (RGBColor(red: 36, green: 200, blue: 219), 0.65, .solid, 0)
        case .ready: (.green, 0.55, .solid, 0)
        case .unavailable: (RGBColor(red: 255, green: 180, blue: 0), 0.28, .shallowBreath, 0.25)
        }
    }
}
