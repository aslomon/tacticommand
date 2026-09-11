import CreatorMicroCore

enum MacShortcutEventKey: Equatable, Sendable {
    case modifier(KeyboardModifier)
    case main(KeyShortcutKey)
}

struct MacShortcutEventDescriptor: Equatable, Sendable {
    let key: MacShortcutEventKey
    let phase: ButtonPhase
    let activeModifiers: [KeyboardModifier]
}

struct MacShortcutEventPlanner: Sendable {
    func events(
        for shortcut: KeyShortcut,
        phase: ButtonPhase
    ) -> [MacShortcutEventDescriptor] {
        switch phase {
        case .pressed: pressEvents(for: shortcut)
        case .released: releaseEvents(for: shortcut)
        }
    }

    func tapEvents(for shortcut: KeyShortcut) -> [MacShortcutEventDescriptor] {
        pressEvents(for: shortcut) + releaseEvents(for: shortcut)
    }

    private func pressEvents(
        for shortcut: KeyShortcut
    ) -> [MacShortcutEventDescriptor] {
        var activeModifiers: [KeyboardModifier] = []
        var events = shortcut.modifiers.map { modifier in
            activeModifiers.append(modifier)
            return descriptor(
                key: .modifier(modifier),
                phase: .pressed,
                activeModifiers: activeModifiers
            )
        }
        events += shortcut.mainKeys.map { key in
            descriptor(
                key: .main(key),
                phase: .pressed,
                activeModifiers: mainModifiers(
                    key: key,
                    phase: .pressed,
                    modifiers: activeModifiers
                )
            )
        }
        return events
    }

    private func releaseEvents(
        for shortcut: KeyShortcut
    ) -> [MacShortcutEventDescriptor] {
        var activeModifiers = shortcut.modifiers
        var events = shortcut.mainKeys.reversed().map { key in
            descriptor(
                key: .main(key),
                phase: .released,
                activeModifiers: mainModifiers(
                    key: key,
                    phase: .released,
                    modifiers: activeModifiers
                )
            )
        }
        for modifier in shortcut.modifiers.reversed() {
            activeModifiers.removeAll { $0 == modifier }
            events.append(
                descriptor(
                    key: .modifier(modifier),
                    phase: .released,
                    activeModifiers: activeModifiers
                )
            )
        }
        return events
    }

    private func mainModifiers(
        key: KeyShortcutKey,
        phase: ButtonPhase,
        modifiers: [KeyboardModifier]
    ) -> [KeyboardModifier] {
        var active = modifiers
        if let representedModifier = key.representedModifier {
            if phase == .pressed, !active.contains(representedModifier) {
                active.append(representedModifier)
            } else if phase == .released {
                active.removeAll { $0 == representedModifier }
            }
        }
        let requested = Set(active)
        return KeyboardModifier.allCases.filter(requested.contains)
    }

    private func descriptor(
        key: MacShortcutEventKey,
        phase: ButtonPhase,
        activeModifiers: [KeyboardModifier]
    ) -> MacShortcutEventDescriptor {
        MacShortcutEventDescriptor(
            key: key,
            phase: phase,
            activeModifiers: activeModifiers
        )
    }
}
