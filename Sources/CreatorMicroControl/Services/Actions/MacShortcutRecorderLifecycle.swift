import CoreGraphics

struct MacShortcutRecorderLifecycle: Equatable, Sendable {
    struct CompletionToken: Equatable, Sendable {
        fileprivate let rawValue: UInt64
    }

    static let fallbackDelay = Duration.milliseconds(750)

    private enum Phase: Equatable, Sendable {
        case idle
        case capturing
        case awaitingKeyUp(CGKeyCode, CompletionToken)
    }

    private var phase = Phase.idle
    private var nextTokenValue: UInt64 = 0

    var isActive: Bool {
        phase != .idle
    }

    var acceptsShortcut: Bool {
        phase == .capturing
    }

    mutating func start() {
        phase = .capturing
    }

    mutating func awaitKeyUp(_ keyCode: CGKeyCode) -> CompletionToken? {
        guard phase == .capturing else { return nil }
        nextTokenValue &+= 1
        let token = CompletionToken(rawValue: nextTokenValue)
        phase = .awaitingKeyUp(keyCode, token)
        return token
    }

    mutating func consumeKeyUp(_ keyCode: CGKeyCode) -> Bool {
        guard case .awaitingKeyUp(let expectedKeyCode, _) = phase,
            keyCode == expectedKeyCode
        else {
            return false
        }
        stop()
        return true
    }

    mutating func consumeTimeout(_ token: CompletionToken) -> Bool {
        guard case .awaitingKeyUp(_, let activeToken) = phase,
            token == activeToken
        else {
            return false
        }
        stop()
        return true
    }

    mutating func stop() {
        phase = .idle
    }
}
