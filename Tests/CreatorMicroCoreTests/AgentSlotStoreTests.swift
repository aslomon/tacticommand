import Foundation
import XCTest

@testable import CreatorMicroCore

final class AgentSlotStoreTests: XCTestCase {
    func testEmptyStoreAlwaysExposesSixUnavailableSlots() async {
        let store = AgentSlotStore()
        let snapshot = await store.snapshot()

        XCTAssertEqual(snapshot.slots.map(\.id), AgentSlotID.allCases)
        XCTAssertEqual(snapshot.slots.count, 6)
        XCTAssertTrue(snapshot.slots.allSatisfy { $0.session == nil })
        XCTAssertTrue(snapshot.slots.allSatisfy { $0.status == .unavailable })
    }

    func testNormalizationKeepsTheSixMostImportantSessions() async {
        let store = AgentSlotStore()
        let sessions = [
            session("idle", status: .idle, updatedAt: 1),
            session("working", status: .working, updatedAt: 2),
            session("complete", status: .complete, updatedAt: 3),
            session("error", status: .error, updatedAt: 4),
            session("waiting", status: .waiting, updatedAt: 5),
            session("second-working", status: .working, updatedAt: 6),
            session("unavailable", status: .unavailable, updatedAt: 7),
        ]

        let snapshot = await store.ingest(sessions, from: .codexAppServer)
        let identifiers = Set(snapshot.slots.compactMap(\.session?.id.externalID))

        XCTAssertEqual(identifiers.count, 6)
        XCTAssertTrue(identifiers.contains("idle"))
        XCTAssertFalse(identifiers.contains("unavailable"))
    }

    func testExistingSessionsKeepTheirPhysicalSlotsAcrossUpdates() async {
        let store = AgentSlotStore()
        let initial = await store.ingest(
            [
                session("alpha", status: .working, updatedAt: 1),
                session("beta", status: .idle, updatedAt: 2),
            ],
            from: .codexAppServer
        )
        let alphaSlot = initial.slots.first { $0.session?.id.externalID == "alpha" }?.id

        let updated = await store.ingest(
            [
                session("alpha", status: .waiting, updatedAt: 4),
                session("gamma", status: .error, updatedAt: 5),
                session("beta", status: .working, updatedAt: 3),
            ],
            from: .codexAppServer
        )

        let updatedAlpha = updated.slots.first {
            $0.session?.id.externalID == "alpha"
        }
        XCTAssertEqual(updatedAlpha?.id, alphaSlot)
        XCTAssertEqual(updatedAlpha?.status, .waiting)
    }

    func testFailingAdapterClearsOnlyItsSourceAndReportsUnavailable() async {
        let codex = StubAdapter(
            source: .codexAppServer,
            sessions: [session("codex", status: .working, updatedAt: 1)],
            failure: true
        )
        let claudeSession = session(
            "claude",
            source: .claudeHooks,
            status: .waiting,
            updatedAt: 2
        )
        let claude = StubAdapter(source: .claudeHooks, sessions: [claudeSession])
        let adapters: [any AgentSessionAdapter] = [codex, claude]
        let store = AgentSlotStore(adapters: adapters)

        let snapshot = await store.refresh()

        XCTAssertEqual(snapshot.sessions, [claudeSession])
        XCTAssertEqual(
            snapshot.adapterAvailability[.codexAppServer],
            .unavailable(.fetchFailed)
        )
        XCTAssertEqual(snapshot.adapterAvailability[.claudeHooks], .available)
    }

    func testMismatchedAdapterPayloadIsRejected() async {
        let mismatched = session(
            "claude-from-codex",
            source: .claudeHooks,
            status: .working,
            updatedAt: 1
        )
        let adapter = StubAdapter(source: .codexAppServer, sessions: [mismatched])
        let adapters: [any AgentSessionAdapter] = [adapter]
        let store = AgentSlotStore(adapters: adapters)

        let snapshot = await store.refresh()

        XCTAssertTrue(snapshot.sessions.isEmpty)
        XCTAssertEqual(
            snapshot.adapterAvailability[.codexAppServer],
            .unavailable(.invalidPayload)
        )
    }

    func testKnownUnavailableSourceIsNotReportedAsGenericFailure() async {
        let adapter = UnavailableAdapter(source: .claudeHooks)
        let adapters: [any AgentSessionAdapter] = [adapter]
        let store = AgentSlotStore(adapters: adapters)

        let snapshot = await store.refresh()

        XCTAssertEqual(
            snapshot.adapterAvailability[.claudeHooks],
            .unavailable(.sourceUnavailable)
        )
    }

    func testFocusUsesTheOwningAdapterCapability() async {
        let recorder = FocusRecorder()
        let focusTarget = AgentFocusTarget.codexThread(threadID: "thread-1")
        let focusedSession = session(
            "focusable",
            status: .waiting,
            updatedAt: 1,
            focusTarget: focusTarget
        )
        let adapter = StubAdapter(
            source: .codexAppServer,
            sessions: [focusedSession],
            focusCapabilities: [.codexThread],
            recorder: recorder
        )
        let adapters: [any AgentSessionAdapter] = [adapter]
        let store = AgentSlotStore(adapters: adapters)
        let snapshot = await store.refresh()
        let slotID = snapshot.slots.first { $0.session?.id == focusedSession.id }?.id

        let result = await store.focus(slot: slotID ?? .one)
        let targets = await recorder.targets

        XCTAssertEqual(result, .focused)
        XCTAssertEqual(targets, [focusTarget])
    }

    func testFocusFallsBackSafelyForEmptyUnsupportedAndFailedTargets() async {
        let emptyStore = AgentSlotStore()
        let emptyResult = await emptyStore.focus(slot: .one)
        XCTAssertEqual(emptyResult, .unavailable(.emptySlot))

        let target = AgentFocusTarget.process(processIdentifier: 42)
        let unsupportedSession = session(
            "unsupported",
            status: .waiting,
            updatedAt: 1,
            focusTarget: target
        )
        let unsupportedAdapter = StubAdapter(
            source: .codexAppServer,
            sessions: [unsupportedSession],
            focusCapabilities: []
        )
        let unsupportedAdapters: [any AgentSessionAdapter] = [unsupportedAdapter]
        let unsupportedStore = AgentSlotStore(adapters: unsupportedAdapters)
        _ = await unsupportedStore.refresh()
        let unsupportedResult = await unsupportedStore.focus(slot: .one)
        XCTAssertEqual(unsupportedResult, .unavailable(.unsupportedTarget))

        let failedAdapter = StubAdapter(
            source: .codexAppServer,
            sessions: [unsupportedSession],
            focusCapabilities: [.process],
            focusFailure: true
        )
        let failedAdapters: [any AgentSessionAdapter] = [failedAdapter]
        let failedStore = AgentSlotStore(adapters: failedAdapters)
        _ = await failedStore.refresh()
        let failedResult = await failedStore.focus(slot: .one)
        XCTAssertEqual(failedResult, .unavailable(.focusFailed))
    }
}

private func session(
    _ externalID: String,
    source: AgentSource = .codexAppServer,
    status: AgentStatus,
    updatedAt: TimeInterval,
    focusTarget: AgentFocusTarget? = nil
) -> AgentSession {
    AgentSession(
        id: AgentSessionID(source: source, externalID: externalID),
        title: externalID,
        detail: nil,
        status: status,
        updatedAt: Date(timeIntervalSince1970: updatedAt),
        focusTarget: focusTarget
    )
}

private struct StubFailure: Error {}

private struct UnavailableAdapter: AgentSessionAdapter {
    let source: AgentSource

    func fetchSessions() async throws -> [AgentSession] {
        throw AgentSessionAdapterError.sourceUnavailable
    }
}

private struct StubAdapter: AgentSessionAdapter {
    let source: AgentSource
    let sessions: [AgentSession]
    let focusCapabilities: Set<AgentFocusCapability>
    let recorder: FocusRecorder?
    let failure: Bool
    let focusFailure: Bool

    init(
        source: AgentSource,
        sessions: [AgentSession],
        focusCapabilities: Set<AgentFocusCapability> = [],
        recorder: FocusRecorder? = nil,
        failure: Bool = false,
        focusFailure: Bool = false
    ) {
        self.source = source
        self.sessions = sessions
        self.focusCapabilities = focusCapabilities
        self.recorder = recorder
        self.failure = failure
        self.focusFailure = focusFailure
    }

    func fetchSessions() async throws -> [AgentSession] {
        if failure {
            throw StubFailure()
        }
        return sessions
    }

    func focus(_ target: AgentFocusTarget) async throws {
        if focusFailure {
            throw StubFailure()
        }
        await recorder?.record(target)
    }
}

private actor FocusRecorder {
    private(set) var targets: [AgentFocusTarget] = []

    func record(_ target: AgentFocusTarget) {
        targets.append(target)
    }
}
