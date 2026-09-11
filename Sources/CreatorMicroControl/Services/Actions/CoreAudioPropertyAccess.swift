import CoreAudio

struct CoreAudioPropertyAccess: Sendable {
    private let maximumChannelCount: AudioObjectPropertyElement = 64

    func defaultDevice(
        isInput: Bool
    ) -> Result<AudioDeviceID, SystemAudioFailure> {
        var address = AudioObjectPropertyAddress(
            mSelector: isInput
                ? kAudioHardwarePropertyDefaultInputDevice
                : kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        guard status == noErr, device != kAudioObjectUnknown else {
            return .failure(.defaultDeviceUnavailable(isInput: isInput, status: status))
        }
        return .success(device)
    }

    func scope(isInput: Bool) -> AudioObjectPropertyScope {
        isInput ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
    }

    func elements(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        writable: Bool = false
    ) -> [AudioObjectPropertyElement] {
        let main = kAudioObjectPropertyElementMain
        if supports(
            device: device,
            selector: selector,
            scope: scope,
            element: main,
            writable: writable
        ) {
            return [main]
        }
        return (1...maximumChannelCount).filter { element in
            supports(
                device: device,
                selector: selector,
                scope: scope,
                element: element,
                writable: writable
            )
        }
    }

    func hasProperty(
        device: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) -> Bool {
        var mutableAddress = address
        return AudioObjectHasProperty(device, &mutableAddress)
    }

    func readUInt32Values(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        elements: [AudioObjectPropertyElement]
    ) -> Result<[UInt32], SystemAudioFailure> {
        readValues(elements: elements) { element in
            readUInt32(
                device: device,
                selector: selector,
                scope: scope,
                element: element
            )
        }
    }

    func readFloat32Values(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        elements: [AudioObjectPropertyElement]
    ) -> Result<[Float32], SystemAudioFailure> {
        readValues(elements: elements) { element in
            readFloat32(
                device: device,
                selector: selector,
                scope: scope,
                element: element
            )
        }
    }

    func writeUInt32(
        _ value: UInt32,
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Result<Void, SystemAudioFailure> {
        var mutableValue = value
        return write(
            &mutableValue,
            device: device,
            selector: selector,
            scope: scope,
            element: element
        )
    }

    func writeFloat32(
        _ value: Float32,
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Result<Void, SystemAudioFailure> {
        var mutableValue = value
        return write(
            &mutableValue,
            device: device,
            selector: selector,
            scope: scope,
            element: element
        )
    }

    private func supports(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement,
        writable: Bool
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        guard AudioObjectHasProperty(device, &address) else { return false }
        guard writable else { return true }
        var isSettable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &address, &isSettable) == noErr
            && isSettable.boolValue
    }

    private func readUInt32(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Result<UInt32, SystemAudioFailure> {
        var value: UInt32 = 0
        let result = read(
            &value,
            device: device,
            selector: selector,
            scope: scope,
            element: element
        )
        return result.map { value }
    }

    private func readFloat32(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Result<Float32, SystemAudioFailure> {
        var value: Float32 = 0
        let result = read(
            &value,
            device: device,
            selector: selector,
            scope: scope,
            element: element
        )
        return result.map { value }
    }

    private func read<Value>(
        _ value: inout Value,
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Result<Void, SystemAudioFailure> {
        var size = UInt32(MemoryLayout<Value>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            guard let baseAddress = buffer.baseAddress else { return kAudio_ParamError }
            return AudioObjectGetPropertyData(
                device,
                &address,
                0,
                nil,
                &size,
                baseAddress
            )
        }
        return status == noErr ? .success(()) : .failure(.operationFailed(status))
    }

    private func write<Value>(
        _ value: inout Value,
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Result<Void, SystemAudioFailure> {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        let status = withUnsafeBytes(of: &value) { buffer in
            guard let baseAddress = buffer.baseAddress else { return kAudio_ParamError }
            return AudioObjectSetPropertyData(
                device,
                &address,
                0,
                nil,
                UInt32(buffer.count),
                baseAddress
            )
        }
        return status == noErr ? .success(()) : .failure(.operationFailed(status))
    }

    private func readValues<Value>(
        elements: [AudioObjectPropertyElement],
        read: (AudioObjectPropertyElement) -> Result<Value, SystemAudioFailure>
    ) -> Result<[Value], SystemAudioFailure> {
        guard !elements.isEmpty else { return .success([]) }
        var values: [Value] = []
        for element in elements {
            switch read(element) {
            case .success(let value): values.append(value)
            case .failure(let failure): return .failure(failure)
            }
        }
        return .success(values)
    }
}
