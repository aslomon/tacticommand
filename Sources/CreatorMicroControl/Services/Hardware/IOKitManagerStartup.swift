import IOKit.hid

enum IOKitManagerStartupState: Equatable, Sendable {
    case created
    case opened
    case dispatchConfigured
    case active
}

struct IOKitManagerStartup {
    private(set) var state = IOKitManagerStartupState.created

    mutating func run(
        open: () -> IOReturn,
        configureDispatch: () -> Void,
        activate: () -> Void
    ) -> IOReturn {
        precondition(state == .created)
        let result = open()
        guard result == kIOReturnSuccess else { return result }
        state = .opened
        configureDispatch()
        state = .dispatchConfigured
        activate()
        state = .active
        return result
    }
}
