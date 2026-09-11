public enum AudioMuteState: String, Codable, Hashable, Sendable {
    case muted
    case unmuted
    case mixed
    case unavailable

    public init(channelValues: [Bool]) {
        guard let first = channelValues.first else {
            self = .unavailable
            return
        }
        self =
            channelValues.dropFirst().allSatisfy { $0 == first }
            ? (first ? .muted : .unmuted)
            : .mixed
    }
}

public struct SystemAudioSnapshot: Codable, Equatable, Sendable {
    public let inputMute: AudioMuteState
    public let outputMute: AudioMuteState
    public let outputVolume: Double?

    public init(
        inputMute: AudioMuteState,
        outputMute: AudioMuteState,
        outputVolume: Double?
    ) {
        self.inputMute = inputMute
        self.outputMute = outputMute
        self.outputVolume = outputVolume
    }

    public static let unavailable = SystemAudioSnapshot(
        inputMute: .unavailable,
        outputMute: .unavailable,
        outputVolume: nil
    )
}

public struct AudioVolumePlanner: Sendable {
    public init() {}

    public func values(
        after command: VolumeCommand,
        currentValues: [Double],
        step: Double
    ) -> [Double] {
        guard let reference = currentValues.max(),
            let quietest = currentValues.min()
        else {
            return []
        }
        let requestedDelta = targetDelta(
            command: command,
            reference: reference,
            step: step
        )
        let delta = min(
            max(requestedDelta, -quietest),
            1 - reference
        )
        return currentValues.map { clamped($0 + delta) }
    }

    private func targetDelta(
        command: VolumeCommand,
        reference: Double,
        step: Double
    ) -> Double {
        switch command {
        case .increase: abs(step)
        case .decrease: -abs(step)
        case .set(let value): clamped(value) - reference
        }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
