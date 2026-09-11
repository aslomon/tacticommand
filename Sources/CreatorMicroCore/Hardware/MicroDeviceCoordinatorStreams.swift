import Foundation

extension MicroDeviceCoordinator {
    public func makeUpdateStream() -> AsyncStream<MicroCoordinatorUpdate> {
        makeUpdateStream(kind: .all, bufferingPolicy: .bufferingNewest(256))
    }

    public func makeDiscreteUpdateStream() -> AsyncStream<MicroCoordinatorUpdate> {
        makeUpdateStream(kind: .discrete, bufferingPolicy: .unbounded)
    }

    public func makeRadialUpdateStream() -> AsyncStream<SequencedRadialUpdate> {
        let identifier = UUID()
        let stream = AsyncStream<SequencedRadialUpdate>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        radialUpdateContinuations[identifier] = stream.continuation
        stream.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeRadialUpdateContinuation(identifier) }
        }
        return stream.stream
    }

    public func makeJoystickSafetyUpdateStream() -> AsyncStream<SequencedConnectionUpdate> {
        let identifier = UUID()
        let stream = AsyncStream<SequencedConnectionUpdate>.makeStream(
            bufferingPolicy: .unbounded
        )
        connectionUpdateContinuations[identifier] = stream.continuation
        stream.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeConnectionUpdateContinuation(identifier) }
        }
        stream.continuation.yield(
            SequencedConnectionUpdate(
                sequence: connectionStateSequence,
                state: connectionState
            )
        )
        return stream.stream
    }

    public func sequencedConnectionSnapshot() -> SequencedConnectionUpdate {
        SequencedConnectionUpdate(sequence: connectionStateSequence, state: connectionState)
    }

    func publish(_ update: MicroCoordinatorUpdate) {
        updateSequence &+= 1
        updateVerifiedConnectionSequence(for: update)
        for subscriber in updateSubscribers.values where subscriber.kind.accepts(update) {
            subscriber.continuation.yield(update)
        }
        publishSpecialized(update, sequence: updateSequence)
    }

    private func makeUpdateStream(
        kind: MicroUpdateStreamKind,
        bufferingPolicy: AsyncStream<MicroCoordinatorUpdate>.Continuation.BufferingPolicy
    ) -> AsyncStream<MicroCoordinatorUpdate> {
        let identifier = UUID()
        let stream = AsyncStream<MicroCoordinatorUpdate>.makeStream(
            bufferingPolicy: bufferingPolicy
        )
        updateSubscribers[identifier] = MicroUpdateSubscriber(
            kind: kind,
            continuation: stream.continuation
        )
        stream.continuation.onTermination = { [weak self] _ in
            Task { await self?.removeUpdateContinuation(identifier) }
        }
        stream.continuation.yield(.connection(connectionState))
        return stream.stream
    }

    private func publishSpecialized(_ update: MicroCoordinatorUpdate, sequence: UInt64) {
        switch update {
        case .event(.radial(let input)):
            let sequenced = SequencedRadialUpdate(
                sequence: sequence,
                connectionSequence: verifiedConnectionSequence,
                input: input
            )
            for continuation in radialUpdateContinuations.values {
                continuation.yield(sequenced)
            }
        case .connection(let state):
            let sequenced = SequencedConnectionUpdate(sequence: sequence, state: state)
            for continuation in connectionUpdateContinuations.values {
                continuation.yield(sequenced)
            }
        default:
            break
        }
    }

    private func updateVerifiedConnectionSequence(for update: MicroCoordinatorUpdate) {
        guard case .connection(let state) = update else { return }
        connectionStateSequence = updateSequence
        if case .connected = state {
            verifiedConnectionSequence = updateSequence
        } else {
            verifiedConnectionSequence = nil
        }
    }

    private func removeUpdateContinuation(_ identifier: UUID) {
        updateSubscribers[identifier] = nil
    }

    private func removeRadialUpdateContinuation(_ identifier: UUID) {
        radialUpdateContinuations[identifier] = nil
    }

    private func removeConnectionUpdateContinuation(_ identifier: UUID) {
        connectionUpdateContinuations[identifier] = nil
    }
}
