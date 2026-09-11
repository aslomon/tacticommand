import Foundation

struct MicroUpdateSubscriber {
    let kind: MicroUpdateStreamKind
    let continuation: AsyncStream<MicroCoordinatorUpdate>.Continuation
}

enum MicroUpdateStreamKind {
    case all
    case discrete

    func accepts(_ update: MicroCoordinatorUpdate) -> Bool {
        switch self {
        case .all:
            true
        case .discrete:
            if case .event(.radial) = update { false } else { true }
        }
    }
}

public struct SequencedRadialUpdate: Equatable, Sendable {
    public let sequence: UInt64
    public let connectionSequence: UInt64?
    public let input: RadialInputEvent

    public init(
        sequence: UInt64,
        connectionSequence: UInt64?,
        input: RadialInputEvent
    ) {
        self.sequence = sequence
        self.connectionSequence = connectionSequence
        self.input = input
    }
}

public struct SequencedConnectionUpdate: Equatable, Sendable {
    public let sequence: UInt64
    public let state: DeviceConnectionState

    public init(sequence: UInt64, state: DeviceConnectionState) {
        self.sequence = sequence
        self.state = state
    }
}
