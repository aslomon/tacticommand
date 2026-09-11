import CoreAudio
import CreatorMicroCore

public enum SystemAudioFailure: Error, Equatable, Sendable {
    case defaultDeviceUnavailable(isInput: Bool, status: OSStatus)
    case propertyUnavailable(String)
    case operationFailed(OSStatus)
}

public protocol SystemAudioControlling: Sendable {
    func snapshot() -> SystemAudioSnapshot

    func applyOutputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure>

    func applyInputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure>

    func applyVolume(
        _ command: VolumeCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure>
}

public struct SystemAudioController: SystemAudioControlling, Sendable {
    private let volumeStep: Double
    private let access = CoreAudioPropertyAccess()
    private let volumePlanner = AudioVolumePlanner()

    public init(volumeStep: Float32 = 0.0625) {
        self.volumeStep = min(max(Double(volumeStep), 0.01), 0.5)
    }

    public func snapshot() -> SystemAudioSnapshot {
        SystemAudioSnapshot(
            inputMute: muteState(isInput: true),
            outputMute: muteState(isInput: false),
            outputVolume: outputVolume()
        )
    }

    public func applyOutputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        applyMute(command, isInput: false)
    }

    public func applyInputMute(
        _ command: MuteCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        applyMute(command, isInput: true)
    }

    public func applyVolume(
        _ command: VolumeCommand
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        switch access.defaultDevice(isInput: false) {
        case .success(let device):
            return updateVolume(command, device: device)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func applyMute(
        _ command: MuteCommand,
        isInput: Bool
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        switch access.defaultDevice(isInput: isInput) {
        case .success(let device):
            return updateMute(command, device: device, isInput: isInput)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func updateMute(
        _ command: MuteCommand,
        device: AudioDeviceID,
        isInput: Bool
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        let scope = access.scope(isInput: isInput)
        let elements = access.elements(
            device: device,
            selector: kAudioDevicePropertyMute,
            scope: scope,
            writable: true
        )
        guard !elements.isEmpty else {
            return .failure(.propertyUnavailable(isInput ? "input mute" : "output mute"))
        }
        switch readMuteValues(device: device, scope: scope, elements: elements) {
        case .success(let values):
            return writeMute(
                targetMuteValue(command: command, currentValues: values),
                device: device,
                scope: scope,
                elements: elements
            )
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func writeMute(
        _ value: UInt32,
        device: AudioDeviceID,
        scope: AudioObjectPropertyScope,
        elements: [AudioObjectPropertyElement]
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        for element in elements {
            if case .failure(let failure) = access.writeUInt32(
                value,
                device: device,
                selector: kAudioDevicePropertyMute,
                scope: scope,
                element: element
            ) {
                return .failure(failure)
            }
        }
        return .success(snapshot())
    }

    private func updateVolume(
        _ command: VolumeCommand,
        device: AudioDeviceID
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        let scope = kAudioObjectPropertyScopeOutput
        let elements = access.elements(
            device: device,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: scope,
            writable: true
        )
        guard !elements.isEmpty else {
            return .failure(.propertyUnavailable("output volume"))
        }
        switch readVolumeValues(device: device, elements: elements) {
        case .success(let values):
            let targets = volumePlanner.values(
                after: command,
                currentValues: values,
                step: volumeStep
            )
            return writeVolume(targets, device: device, elements: elements)
        case .failure(let failure):
            return .failure(failure)
        }
    }

    private func writeVolume(
        _ values: [Double],
        device: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) -> Result<SystemAudioSnapshot, SystemAudioFailure> {
        for (element, value) in zip(elements, values) {
            if case .failure(let failure) = access.writeFloat32(
                Float32(value),
                device: device,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: element
            ) {
                return .failure(failure)
            }
        }
        return .success(snapshot())
    }

    private func muteState(isInput: Bool) -> AudioMuteState {
        guard case .success(let device) = access.defaultDevice(isInput: isInput) else {
            return .unavailable
        }
        let scope = access.scope(isInput: isInput)
        let elements = access.elements(
            device: device,
            selector: kAudioDevicePropertyMute,
            scope: scope
        )
        guard
            case .success(let values) = readMuteValues(
                device: device,
                scope: scope,
                elements: elements
            )
        else {
            return .unavailable
        }
        return AudioMuteState(channelValues: values)
    }

    private func outputVolume() -> Double? {
        guard case .success(let device) = access.defaultDevice(isInput: false) else {
            return nil
        }
        let elements = access.elements(
            device: device,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioObjectPropertyScopeOutput
        )
        guard
            case .success(let values) = readVolumeValues(
                device: device,
                elements: elements
            )
        else {
            return nil
        }
        return values.max()
    }

    private func readMuteValues(
        device: AudioDeviceID,
        scope: AudioObjectPropertyScope,
        elements: [AudioObjectPropertyElement]
    ) -> Result<[Bool], SystemAudioFailure> {
        access.readUInt32Values(
            device: device,
            selector: kAudioDevicePropertyMute,
            scope: scope,
            elements: elements
        ).map { $0.map { $0 != 0 } }
    }

    private func readVolumeValues(
        device: AudioDeviceID,
        elements: [AudioObjectPropertyElement]
    ) -> Result<[Double], SystemAudioFailure> {
        access.readFloat32Values(
            device: device,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioObjectPropertyScopeOutput,
            elements: elements
        ).map { $0.map(Double.init) }
    }

    private func targetMuteValue(
        command: MuteCommand,
        currentValues: [Bool]
    ) -> UInt32 {
        switch command {
        case .toggle:
            AudioMuteState(channelValues: currentValues) == .muted ? 0 : 1
        case .mute: 1
        case .unmute: 0
        }
    }
}
