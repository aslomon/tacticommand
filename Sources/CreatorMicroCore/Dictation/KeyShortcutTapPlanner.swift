public enum KeyShortcutTapStep: Equatable, Sendable {
    case keyDown
    case keyUp
    case wait(milliseconds: Int)
}

public struct KeyShortcutTapPlanner: Sendable {
    public init() {}

    public func steps(for shortcut: KeyShortcut) -> [KeyShortcutTapStep] {
        var steps: [KeyShortcutTapStep] = []
        for index in 0..<shortcut.pressCount {
            steps.append(.keyDown)
            steps.append(.keyUp)
            if index < shortcut.pressCount - 1 {
                steps.append(
                    .wait(milliseconds: shortcut.interTapIntervalMilliseconds)
                )
            }
        }
        return steps
    }
}
