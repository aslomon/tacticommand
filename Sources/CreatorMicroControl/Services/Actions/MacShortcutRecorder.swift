import ApplicationServices
import CoreGraphics
import CreatorMicroCore
import Foundation

enum MacShortcutRecorderFailure: Error, Equatable, Sendable {
    case accessibilityPermissionRequired
    case eventTapUnavailable
}

enum MacShortcutRecorderSafetyResponse: Equatable, Sendable {
    case record
    case cancelAndPassThrough
}

struct MacShortcutRecorderSafetyPolicy: Sendable {
    static func response(
        key: String?,
        modifiers: [KeyboardModifier]
    ) -> MacShortcutRecorderSafetyResponse {
        let normalizedKey = key?.lowercased()
        let modifierSet = Set(modifiers)
        if normalizedKey == "q", modifierSet.contains(.command) {
            return .cancelAndPassThrough
        }
        if normalizedKey == "escape",
            modifierSet.isSuperset(of: [.option, .command])
        {
            return .cancelAndPassThrough
        }
        return .record
    }
}

private final class MacShortcutRecorderResources: @unchecked Sendable {
    var eventTap: CFMachPort?
    var runLoopSource: CFRunLoopSource?

    func tearDown() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit {
        tearDown()
    }
}

@MainActor
final class MacShortcutRecorder {
    private let resources = MacShortcutRecorderResources()
    private var lifecycle = MacShortcutRecorderLifecycle()
    private var completionFallbackTask: Task<Void, Never>?
    private var onDecision: ((ShortcutRecordingDecision) -> Void)?
    private var chordTracker = MacShortcutChordTracker()

    var isRecording: Bool { lifecycle.isActive }

    deinit {
        completionFallbackTask?.cancel()
        resources.tearDown()
    }

    func start(
        onDecision: @escaping (ShortcutRecordingDecision) -> Void
    ) -> Result<Void, MacShortcutRecorderFailure> {
        cancel(notify: false)
        chordTracker.reset()
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionRequired)
        }
        self.onDecision = onDecision
        guard let tap = makeEventTap(),
            let source = CFMachPortCreateRunLoopSource(
                kCFAllocatorDefault,
                tap,
                0
            )
        else {
            self.onDecision = nil
            return .failure(.eventTapUnavailable)
        }
        resources.eventTap = tap
        resources.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        lifecycle.start()
        return .success(())
    }

    func cancel(notify: Bool = true) {
        guard isRecording || resources.eventTap != nil else { return }
        let callback = onDecision
        finishRecording()
        if notify { callback?(.cancelled) }
    }

    nonisolated private func handleEventTap(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let input = Self.recordingInput(type: type, event: event)
        let suppressesEvent = MainActor.assumeIsolated {
            handleEvent(input)
        }
        return suppressesEvent ? nil : Unmanaged.passUnretained(event)
    }

    private func handleEvent(_ input: MacShortcutRecordingInput) -> Bool {
        if input == .tapDisabled {
            completionFallbackTask?.cancel()
            completionFallbackTask = nil
            chordTracker.reset()
            if let eventTap = resources.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return true
        }
        guard isRecording else { return false }
        switch input {
        case .keyDown(let keyCode, let key, let modifiers, let isRepeat):
            if MacShortcutRecorderSafetyPolicy.response(
                key: key,
                modifiers: modifiers
            ) == .cancelAndPassThrough {
                cancel()
                return false
            }
            guard lifecycle.acceptsShortcut else { return true }
            return handleDecision(
                chordTracker.keyDown(
                    key: key,
                    keyCode: keyCode,
                    modifiers: modifiers,
                    isRepeat: isRepeat
                )
            )
        case .keyUp(let keyCode, let modifiers):
            return handleDecision(
                chordTracker.keyUp(
                    keyCode: keyCode,
                    modifiers: modifiers
                )
            )
        case .modifiersChanged(let keyCode, let modifiers):
            let decision =
                chordTracker.modifiersChanged(
                    keyCode: keyCode,
                    modifiers: modifiers
                )
            _ = handleDecision(decision)
            return false
        case .tapDisabled: return true
        case .unrelated: return false
        }
    }

    private func handleDecision(
        _ decision: ShortcutRecordingDecision
    ) -> Bool {
        guard decision == .keepRecording else {
            completeImmediately(with: decision)
            return true
        }
        if chordTracker.isWaitingForModifierRelease {
            scheduleCompletionFallback()
        }
        return true
    }

    private func makeEventTap() -> CFMachPort? {
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<MacShortcutRecorder>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            return recorder.handleEventTap(type: type, event: event)
        }
        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
    }

    private func finishRecording() {
        lifecycle.stop()
        tearDownAfterCompletion()
    }

    private func scheduleCompletionFallback() {
        guard completionFallbackTask == nil else { return }
        completionFallbackTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    for: MacShortcutRecorderLifecycle.fallbackDelay
                )
            } catch {
                return
            }
            guard let self else { return }
            reconcileCompletionFallback()
        }
    }

    private func reconcileCompletionFallback() {
        completionFallbackTask = nil
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let modifiers = MacVirtualKeyMap.modifiers(from: flags)
        let decision = chordTracker.reconcileCurrentModifiers(modifiers)
        if decision != .keepRecording {
            completeImmediately(with: decision)
        } else if chordTracker.isWaitingForModifierRelease {
            scheduleCompletionFallback()
        }
    }

    private func completeImmediately(
        with decision: ShortcutRecordingDecision
    ) {
        let callback = onDecision
        lifecycle.stop()
        tearDownAfterCompletion()
        callback?(decision)
    }

    private func tearDownAfterCompletion() {
        completionFallbackTask?.cancel()
        completionFallbackTask = nil
        tearDownEventTap()
        onDecision = nil
        chordTracker.reset()
    }

    private func tearDownEventTap() {
        resources.tearDown()
    }

    nonisolated private static func recordingInput(
        type: CGEventType,
        event: CGEvent
    ) -> MacShortcutRecordingInput {
        let keyCode = CGKeyCode(
            truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode)
        )
        switch type {
        case .keyDown:
            return .keyDown(
                keyCode: keyCode,
                key: MacVirtualKeyMap.keyName(for: keyCode, event: event),
                modifiers: MacVirtualKeyMap.modifiers(from: event.flags),
                isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            )
        case .keyUp:
            return .keyUp(
                keyCode: keyCode,
                modifiers: MacVirtualKeyMap.modifiers(from: event.flags)
            )
        case .flagsChanged:
            return .modifiersChanged(
                keyCode: keyCode,
                modifiers: MacVirtualKeyMap.modifiers(from: event.flags)
            )
        case .tapDisabledByTimeout, .tapDisabledByUserInput: return .tapDisabled
        default: return .unrelated
        }
    }

    private static let eventMask = CGEventMask(
        (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
    )
}

private enum MacShortcutRecordingInput: Equatable, Sendable {
    case keyDown(
        keyCode: CGKeyCode,
        key: String?,
        modifiers: [KeyboardModifier],
        isRepeat: Bool
    )
    case keyUp(
        keyCode: CGKeyCode,
        modifiers: [KeyboardModifier]
    )
    case modifiersChanged(
        keyCode: CGKeyCode,
        modifiers: [KeyboardModifier]
    )
    case tapDisabled
    case unrelated
}
