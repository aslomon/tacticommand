import CoreAudio
import CreatorMicroCore
import Dispatch

enum SystemAudioMonitorChange: Equatable, Sendable {
    case defaultDevice
    case deviceProperty
}

enum SystemAudioMonitorOperation: Equatable, Hashable, Sendable {
    case rebindDeviceListeners
    case publishSnapshot
}

struct SystemAudioMonitorUpdatePlanner: Sendable {
    func operations(
        for change: SystemAudioMonitorChange
    ) -> [SystemAudioMonitorOperation] {
        switch change {
        case .defaultDevice:
            [.rebindDeviceListeners, .publishSnapshot]
        case .deviceProperty:
            [.publishSnapshot]
        }
    }
}

@MainActor
public final class SystemAudioMonitor {
    public let snapshots: AsyncStream<SystemAudioSnapshot>

    private let continuation: AsyncStream<SystemAudioSnapshot>.Continuation
    private let audio: SystemAudioController
    private let access = CoreAudioPropertyAccess()
    private let updatePlanner = SystemAudioMonitorUpdatePlanner()
    private let callbackQueue = DispatchQueue(
        label: "app.creator-micro-control.audio-monitor"
    )
    private var systemRegistrations: [AudioPropertyRegistration] = []
    private var deviceRegistrations: [AudioPropertyRegistration] = []
    private var pendingOperations: Set<SystemAudioMonitorOperation> = []
    private var refreshTask: Task<Void, Never>?
    private var isStarted = false

    private lazy var systemListener = makeListener(change: .defaultDevice)
    private lazy var deviceListener = makeListener(change: .deviceProperty)

    private func makeListener(
        change: SystemAudioMonitorChange
    ) -> AudioObjectPropertyListenerBlock {
        return { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.schedule(change)
            }
        }
    }

    public init(audio: SystemAudioController = SystemAudioController()) {
        var capturedContinuation: AsyncStream<SystemAudioSnapshot>.Continuation?
        snapshots = AsyncStream(bufferingPolicy: .bufferingNewest(1)) {
            capturedContinuation = $0
        }
        guard let capturedContinuation else {
            preconditionFailure("Audio snapshot stream did not provide a continuation")
        }
        continuation = capturedContinuation
        self.audio = audio
    }

    deinit {
        Self.remove(
            registrations: deviceRegistrations,
            callbackQueue: callbackQueue
        )
        Self.remove(
            registrations: systemRegistrations,
            callbackQueue: callbackQueue
        )
        continuation.finish()
    }

    public func start() -> Result<Void, SystemAudioFailure> {
        guard !isStarted else {
            schedule(.deviceProperty)
            return .success(())
        }
        switch registerSystemListeners() {
        case .success:
            isStarted = true
            rebindDeviceListeners()
            schedule(.deviceProperty)
            return .success(())
        case .failure(let failure):
            Self.remove(
                registrations: systemRegistrations,
                callbackQueue: callbackQueue
            )
            systemRegistrations.removeAll()
            return .failure(failure)
        }
    }

    public func stop() {
        guard isStarted else { return }
        refreshTask?.cancel()
        refreshTask = nil
        pendingOperations.removeAll()
        Self.remove(
            registrations: deviceRegistrations,
            callbackQueue: callbackQueue
        )
        Self.remove(
            registrations: systemRegistrations,
            callbackQueue: callbackQueue
        )
        deviceRegistrations.removeAll()
        systemRegistrations.removeAll()
        isStarted = false
    }

    public func refresh() {
        schedule(.deviceProperty)
    }

    private func schedule(_ change: SystemAudioMonitorChange) {
        guard isStarted else { return }
        pendingOperations.formUnion(updatePlanner.operations(for: change))
        startRefreshTaskIfNeeded()
    }

    private func startRefreshTaskIfNeeded() {
        guard isStarted, refreshTask == nil else { return }
        refreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
            await self?.flushPendingOperations()
        }
    }

    private func flushPendingOperations() async {
        let operations = pendingOperations
        pendingOperations.removeAll()
        defer { finishRefreshCycle() }
        guard isStarted else { return }
        if operations.contains(.rebindDeviceListeners) {
            rebindDeviceListeners()
        }
        guard operations.contains(.publishSnapshot) else { return }
        let audio = audio
        let snapshot = await Task.detached(priority: .userInitiated) {
            audio.snapshot()
        }.value
        guard isStarted else { return }
        continuation.yield(snapshot)
    }

    private func finishRefreshCycle() {
        refreshTask = nil
        guard !pendingOperations.isEmpty else { return }
        startRefreshTaskIfNeeded()
    }

    private func registerSystemListeners() -> Result<Void, SystemAudioFailure> {
        for selector in Self.defaultDeviceSelectors {
            let address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            switch register(
                objectID: AudioObjectID(kAudioObjectSystemObject),
                address: address,
                listener: systemListener
            ) {
            case .success(let registration):
                systemRegistrations.append(registration)
            case .failure(let failure):
                return .failure(failure)
            }
        }
        return .success(())
    }

    private func rebindDeviceListeners() {
        Self.remove(
            registrations: deviceRegistrations,
            callbackQueue: callbackQueue
        )
        deviceRegistrations.removeAll()
        registerDeviceListeners(isInput: true)
        registerDeviceListeners(isInput: false)
    }

    private func registerDeviceListeners(isInput: Bool) {
        guard case .success(let device) = access.defaultDevice(isInput: isInput) else {
            return
        }
        let scope = access.scope(isInput: isInput)
        registerDeviceProperty(
            device: device,
            selector: kAudioDevicePropertyMute,
            scope: scope
        )
        if !isInput {
            registerDeviceProperty(
                device: device,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: scope
            )
        }
    }

    private func registerDeviceProperty(
        device: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) {
        let elements = access.elements(
            device: device,
            selector: selector,
            scope: scope
        )
        for element in elements {
            let address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: scope,
                mElement: element
            )
            if case .success(let registration) = register(
                objectID: device,
                address: address,
                listener: deviceListener
            ) {
                deviceRegistrations.append(registration)
            }
        }
    }

    private func register(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress,
        listener: @escaping AudioObjectPropertyListenerBlock
    ) -> Result<AudioPropertyRegistration, SystemAudioFailure> {
        guard access.hasProperty(device: objectID, address: address) else {
            return .failure(.propertyUnavailable("audio status monitoring"))
        }
        var mutableAddress = address
        let status = AudioObjectAddPropertyListenerBlock(
            objectID,
            &mutableAddress,
            callbackQueue,
            listener
        )
        guard status == noErr else { return .failure(.operationFailed(status)) }
        return .success(
            AudioPropertyRegistration(
                objectID: objectID,
                address: address,
                listener: listener
            )
        )
    }

    nonisolated private static func remove(
        registrations: [AudioPropertyRegistration],
        callbackQueue: DispatchQueue
    ) {
        for registration in registrations {
            var address = registration.address
            AudioObjectRemovePropertyListenerBlock(
                registration.objectID,
                &address,
                callbackQueue,
                registration.listener
            )
        }
    }

    private static let defaultDeviceSelectors: [AudioObjectPropertySelector] = [
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioHardwarePropertyDefaultOutputDevice,
    ]
}

private struct AudioPropertyRegistration: @unchecked Sendable {
    let objectID: AudioObjectID
    let address: AudioObjectPropertyAddress
    let listener: AudioObjectPropertyListenerBlock
}
