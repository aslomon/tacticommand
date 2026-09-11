import CoreGraphics
import CreatorMicroCore

struct MacShortcutChordTracker: Sendable {
    private static let functionKeyCode: CGKeyCode = 63

    private var mainKeys: [KeyShortcutKey] = []
    private var pressedKeyCodes: Set<CGKeyCode> = []
    private var involvedModifiers: Set<KeyboardModifier> = []
    private var releaseBlockingModifiers: Set<KeyboardModifier> = []
    private var currentModifiers: Set<KeyboardModifier> = []
    private var functionChordModifiers: Set<KeyboardModifier> = []
    private var terminalDecision: ShortcutRecordingDecision?
    private var acceptsMainKeys = true
    private var functionCandidate = false

    var isWaitingForModifierRelease: Bool {
        hasCapturedInput
            && pressedKeyCodes.isEmpty
            && !releaseBlockingModifiers.isDisjoint(with: currentModifiers)
    }

    mutating func keyDown(
        key: String?,
        keyCode: CGKeyCode,
        modifiers: [KeyboardModifier],
        isRepeat: Bool = false
    ) -> ShortcutRecordingDecision {
        observe(modifiers)
        guard !isRepeat else { return .keepRecording }
        guard !pressedKeyCodes.contains(keyCode) else { return .keepRecording }
        pressedKeyCodes.insert(keyCode)
        guard let key, !key.isEmpty else { return .keepRecording }
        if let decision = terminalDecision(for: key) {
            terminalDecision = decision
            involvedModifiers.formUnion(modifiers)
            acceptsMainKeys = false
            return .keepRecording
        }
        guard acceptsMainKeys else { return .keepRecording }
        functionCandidate = false
        involvedModifiers.formUnion(modifiers)
        appendMainKey(key: key, keyCode: keyCode)
        return .keepRecording
    }

    mutating func keyUp(
        keyCode: CGKeyCode,
        modifiers: [KeyboardModifier]
    ) -> ShortcutRecordingDecision {
        observe(modifiers)
        if pressedKeyCodes.remove(keyCode) != nil, hasCapturedInput {
            acceptsMainKeys = false
        }
        return finishIfReady()
    }

    mutating func modifiersChanged(
        keyCode: CGKeyCode,
        modifiers: [KeyboardModifier]
    ) -> ShortcutRecordingDecision {
        let previousModifiers = currentModifiers
        observe(modifiers)
        trackModifiersBeforeRelease(modifiers)
        if !previousModifiers.subtracting(currentModifiers).isEmpty {
            acceptsMainKeys = false
        }
        if keyCode == Self.functionKeyCode {
            handleFunctionChange(modifiers)
        } else if functionCandidate {
            functionChordModifiers.formUnion(nonFunctionModifiers(modifiers))
        }
        return finishIfReady()
    }

    mutating func reconcileCurrentModifiers(
        _ modifiers: [KeyboardModifier]
    ) -> ShortcutRecordingDecision {
        observe(modifiers)
        return finishIfReady()
    }

    mutating func reset() {
        mainKeys = []
        pressedKeyCodes = []
        involvedModifiers = []
        releaseBlockingModifiers = []
        currentModifiers = []
        functionChordModifiers = []
        terminalDecision = nil
        acceptsMainKeys = true
        functionCandidate = false
    }

    private mutating func handleFunctionChange(
        _ modifiers: [KeyboardModifier]
    ) {
        if modifiers.contains(.function) {
            if mainKeys.isEmpty, !functionCandidate {
                functionCandidate = true
                functionChordModifiers = nonFunctionModifiers(modifiers)
            }
            return
        }
        guard functionCandidate, mainKeys.isEmpty else {
            functionCandidate = false
            return
        }
        mainKeys = [KeyShortcutKey(key: "fn", virtualKeyCode: Self.functionKeyCode)]
        involvedModifiers = functionChordModifiers
        acceptsMainKeys = false
        functionCandidate = false
    }

    private mutating func trackModifiersBeforeRelease(
        _ modifiers: [KeyboardModifier]
    ) {
        guard acceptsMainKeys else { return }
        involvedModifiers.formUnion(modifiers)
    }

    private mutating func appendMainKey(
        key: String,
        keyCode: CGKeyCode
    ) {
        guard mainKeys.count < KeyShortcut.maximumMainKeyCount else { return }
        let candidate = KeyShortcutKey(key: key, virtualKeyCode: keyCode)
        guard !mainKeys.contains(where: { $0.virtualKeyCode == keyCode }) else { return }
        mainKeys.append(candidate)
    }

    private mutating func finishIfReady() -> ShortcutRecordingDecision {
        guard pressedKeyCodes.isEmpty,
            hasCapturedInput,
            releaseBlockingModifiers.isDisjoint(with: currentModifiers)
        else {
            return .keepRecording
        }
        let decision = terminalDecision ?? .captured(makeShortcut())
        reset()
        return decision
    }

    private func makeShortcut() -> KeyShortcut {
        KeyShortcut(
            mainKeys: mainKeys,
            modifiers: Array(involvedModifiers)
        )
    }

    private mutating func observe(_ modifiers: [KeyboardModifier]) {
        currentModifiers = Set(modifiers)
        releaseBlockingModifiers.formUnion(modifiers)
    }

    private var hasCapturedInput: Bool {
        !mainKeys.isEmpty || !involvedModifiers.isEmpty || terminalDecision != nil
    }

    private func terminalDecision(
        for key: String
    ) -> ShortcutRecordingDecision? {
        switch key.lowercased() {
        case "escape": .cancelled
        case "delete", "forward-delete", "backspace": .cleared
        default: nil
        }
    }

    private func nonFunctionModifiers(
        _ modifiers: [KeyboardModifier]
    ) -> Set<KeyboardModifier> {
        Set(modifiers.filter { $0 != .function })
    }
}
