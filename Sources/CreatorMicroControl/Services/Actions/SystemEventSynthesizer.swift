import ApplicationServices
import CoreGraphics
import CreatorMicroCore

public enum SystemEventFailure: Error, Equatable, Sendable {
    case accessibilityPermissionRequired
    case unsupportedKey(String)
    case tooManyShortcutKeys(Int)
    case eventCreationFailed
    case cancelled
}

public struct SystemEventSynthesizer: Sendable {
    public init() {}

    public func tap(
        _ shortcut: KeyShortcut
    ) async -> Result<Void, SystemEventFailure> {
        for step in KeyShortcutTapPlanner().steps(for: shortcut) {
            switch step {
            case .keyDown:
                if case .failure(let failure) = send(shortcut, phase: .pressed) {
                    return .failure(failure)
                }
            case .keyUp:
                if case .failure(let failure) = send(shortcut, phase: .released) {
                    return .failure(failure)
                }
            case .wait(let milliseconds):
                do {
                    try await Task.sleep(for: .milliseconds(milliseconds))
                } catch {
                    return .failure(.cancelled)
                }
            }
        }
        return .success(())
    }

    public func send(
        _ shortcut: KeyShortcut,
        phase: ButtonPhase
    ) -> Result<Void, SystemEventFailure> {
        guard AXIsProcessTrusted() else { return .failure(.accessibilityPermissionRequired) }
        guard shortcut.mainKeys.count <= KeyShortcut.maximumMainKeyCount else {
            return .failure(.tooManyShortcutKeys(shortcut.mainKeys.count))
        }
        switch makeKeyboardEvents(shortcut, phase: phase) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let events):
            for event in events { event.post(tap: .cghidEventTap) }
            return .success(())
        }
    }

    public func releaseForCleanup(
        _ shortcut: KeyShortcut
    ) -> Result<Void, SystemEventFailure> {
        guard shortcut.mainKeys.count <= KeyShortcut.maximumMainKeyCount else {
            return .failure(.tooManyShortcutKeys(shortcut.mainKeys.count))
        }
        switch makeKeyboardEvents(shortcut, phase: .released) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let events):
            for event in events { event.post(tap: .cghidEventTap) }
            return .success(())
        }
    }

    public func repeatKey(
        _ shortcut: KeyShortcut
    ) -> Result<Void, SystemEventFailure> {
        guard AXIsProcessTrusted() else { return .failure(.accessibilityPermissionRequired) }
        switch makeKeyboardEvents(shortcut, phase: .pressed) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let events):
            for event in events {
                event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
                event.post(tap: .cghidEventTap)
            }
            return .success(())
        }
    }

    public func typeText(_ text: String) -> Result<Void, SystemEventFailure> {
        guard AXIsProcessTrusted() else { return .failure(.accessibilityPermissionRequired) }
        guard
            let keyDown = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: 0,
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: 0,
                keyDown: false
            )
        else {
            return .failure(.eventCreationFailed)
        }
        setUnicodeText(text, on: keyDown)
        setUnicodeText(text, on: keyUp)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return .success(())
    }

    public func switchApplication(
        _ direction: AppSwitchDirection
    ) async -> Result<Void, SystemEventFailure> {
        let modifiers: [KeyboardModifier] =
            direction == .previous
            ? [.command, .shift]
            : [.command]
        return await tap(KeyShortcut(key: "tab", modifiers: modifiers))
    }

    public func switchWindow(
        _ direction: AppSwitchDirection
    ) async -> Result<Void, SystemEventFailure> {
        let modifiers: [KeyboardModifier] =
            direction == .previous
            ? [.command, .shift]
            : [.command]
        return await tap(KeyShortcut(key: "grave", modifiers: modifiers))
    }

    public func perform(
        _ command: PointerCommand
    ) -> Result<Void, SystemEventFailure> {
        guard AXIsProcessTrusted() else { return .failure(.accessibilityPermissionRequired) }
        switch command {
        case .move(let horizontal, let vertical):
            return movePointer(horizontal: horizontal, vertical: vertical)
        case .click(let button):
            return click(button)
        case .scroll(let direction):
            return scroll(direction)
        }
    }

    private var eventSource: CGEventSource? {
        CGEventSource(stateID: .hidSystemState)
    }

    private func makeKeyboardEvents(
        _ shortcut: KeyShortcut,
        phase: ButtonPhase
    ) -> Result<[CGEvent], SystemEventFailure> {
        let descriptors = MacShortcutEventPlanner().events(for: shortcut, phase: phase)
        var events: [CGEvent] = []
        for descriptor in descriptors {
            guard let keyCode = keyCode(for: descriptor.key) else {
                return .failure(.unsupportedKey(keyName(for: descriptor.key)))
            }
            guard let event = keyboardEvent(keyCode: keyCode, phase: descriptor.phase) else {
                return .failure(.eventCreationFailed)
            }
            event.flags = MacVirtualKeyMap.flags(for: descriptor.activeModifiers)
            events.append(event)
        }
        return .success(events)
    }

    private func keyCode(for key: MacShortcutEventKey) -> CGKeyCode? {
        switch key {
        case .modifier(let modifier): MacVirtualKeyMap.keyCode(for: modifier)
        case .main(let mainKey): MacVirtualKeyMap.keyCode(for: mainKey)
        }
    }

    private func keyName(for key: MacShortcutEventKey) -> String {
        switch key {
        case .modifier(let modifier): modifier.rawValue
        case .main(let mainKey): mainKey.key
        }
    }

    private func keyboardEvent(
        keyCode: CGKeyCode,
        phase: ButtonPhase
    ) -> CGEvent? {
        CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: keyCode,
            keyDown: phase == .pressed
        )
    }

    private func setUnicodeText(_ text: String, on event: CGEvent) {
        let characters = Array(text.utf16)
        characters.withUnsafeBufferPointer { buffer in
            event.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: buffer.baseAddress
            )
        }
    }

    private func movePointer(
        horizontal: Int,
        vertical: Int
    ) -> Result<Void, SystemEventFailure> {
        guard let probe = CGEvent(source: eventSource) else {
            return .failure(.eventCreationFailed)
        }
        let destination = CGPoint(
            x: probe.location.x + CGFloat(horizontal),
            y: probe.location.y + CGFloat(vertical)
        )
        guard
            let event = CGEvent(
                mouseEventSource: eventSource,
                mouseType: .mouseMoved,
                mouseCursorPosition: destination,
                mouseButton: .left
            )
        else {
            return .failure(.eventCreationFailed)
        }
        event.post(tap: .cghidEventTap)
        return .success(())
    }

    private func click(_ button: PointerButton) -> Result<Void, SystemEventFailure> {
        guard let probe = CGEvent(source: eventSource) else {
            return .failure(.eventCreationFailed)
        }
        let properties = mouseProperties(for: button)
        guard
            let down = CGEvent(
                mouseEventSource: eventSource,
                mouseType: properties.down,
                mouseCursorPosition: probe.location,
                mouseButton: properties.button
            ),
            let up = CGEvent(
                mouseEventSource: eventSource,
                mouseType: properties.up,
                mouseCursorPosition: probe.location,
                mouseButton: properties.button
            )
        else {
            return .failure(.eventCreationFailed)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return .success(())
    }

    private func scroll(_ direction: ScrollDirection) -> Result<Void, SystemEventFailure> {
        let delta: (vertical: Int32, horizontal: Int32)
        switch direction {
        case .up: delta = (80, 0)
        case .down: delta = (-80, 0)
        case .left: delta = (0, 80)
        case .right: delta = (0, -80)
        }
        guard
            let event = CGEvent(
                scrollWheelEvent2Source: eventSource,
                units: .pixel,
                wheelCount: 2,
                wheel1: delta.vertical,
                wheel2: delta.horizontal,
                wheel3: 0
            )
        else {
            return .failure(.eventCreationFailed)
        }
        event.post(tap: .cghidEventTap)
        return .success(())
    }

    private func mouseProperties(
        for button: PointerButton
    ) -> (down: CGEventType, up: CGEventType, button: CGMouseButton) {
        switch button {
        case .primary: (.leftMouseDown, .leftMouseUp, .left)
        case .secondary: (.rightMouseDown, .rightMouseUp, .right)
        case .middle: (.otherMouseDown, .otherMouseUp, .center)
        }
    }

}
