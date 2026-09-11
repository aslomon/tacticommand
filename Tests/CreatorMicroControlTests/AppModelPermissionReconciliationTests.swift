import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelPermissionReconciliationTests: XCTestCase {
    func testRevocationStopsRuntimeAndClearsActiveInputState() async throws {
        let fixture = makeFixture(transport: PermissionTestTransport())
        fixture.model.startRuntime()
        try await fixture.transport.waitForStatusRequest()
        await fixture.transport.sendStatus()
        try await waitUntilConnected(fixture.model, stage: "initial")
        activateInputState(on: fixture.model)

        fixture.access.currentSnapshot = .deniedForInputMonitoring
        fixture.model.refreshSystemAccess()
        await fixture.model.systemAccessReconciliationTask?.value

        XCTAssertNil(fixture.model.runtimeTask)
        XCTAssertNil(fixture.model.reconnectTask)
        XCTAssertFalse(fixture.model.pointerController.isRunning)
        XCTAssertTrue(fixture.model.pressedControls.isEmpty)
        XCTAssertTrue(releaseActiveControl(on: fixture.model).isEmpty)
        let coordinatorState = await fixture.coordinator.connectionState
        let closeCount = await fixture.transport.closeCount
        XCTAssertEqual(coordinatorState, .disconnected)
        XCTAssertEqual(closeCount, 1)
    }

    func testImmediateRevocationPreventsQueuedGrantFromStartingRuntime() async throws {
        let access = PermissionTestAccessController(snapshot: .deniedForInputMonitoring)
        let connector = PermissionTestConnector(transport: nil)
        let coordinator = makeCoordinator(connector: connector)
        let model = makeModel(access: access, coordinator: coordinator)

        access.currentSnapshot = .granted
        model.refreshSystemAccess()
        access.currentSnapshot = .deniedForInputMonitoring
        model.refreshSystemAccess()
        await model.systemAccessReconciliationTask?.value

        let connectionAttempts = await connector.connectionAttempts
        XCTAssertEqual(connectionAttempts, 0)
        XCTAssertNil(model.runtimeTask)
        XCTAssertEqual(
            model.connectionState,
            .unavailable(reason: SystemAccessPolicy.inputMonitoringRequiredMessage)
        )
    }

    func testRevocationCancelsReconnectBeforeCoordinatorCanRestart() async throws {
        let transport = PermissionTestTransport(blockClose: true)
        let resumedTransport = PermissionTestTransport()
        let fixture = makeFixture(
            transport: transport,
            resumedTransport: resumedTransport
        )
        fixture.model.startRuntime()
        try await transport.waitForStatusRequest()
        await transport.sendStatus()
        try await waitUntilConnected(fixture.model, stage: "initial")

        fixture.model.beginReconnect()
        try await transport.waitUntilCloseStarted()
        fixture.access.currentSnapshot = .deniedForInputMonitoring
        fixture.model.refreshSystemAccess()
        try await waitUntilRuntimeStopped(fixture.model)
        fixture.access.currentSnapshot = .granted
        fixture.model.reconnect()
        await transport.releaseClose()
        try await resumedTransport.waitForStatusRequest()
        await resumedTransport.sendStatus()
        try await waitUntilConnected(fixture.model, stage: "resumed")

        let connectionAttempts = await fixture.connector.connectionAttempts
        let coordinatorState = await fixture.coordinator.connectionState
        XCTAssertEqual(connectionAttempts, 2)
        XCTAssertNil(fixture.model.reconnectTask)
        XCTAssertNotNil(fixture.model.runtimeTask)
        guard case .connected = coordinatorState else {
            return XCTFail("Expected a reconnected coordinator")
        }
        await fixture.model.shutdown()
    }

    private func makeFixture(
        transport: PermissionTestTransport,
        resumedTransport: PermissionTestTransport? = nil
    ) -> PermissionTestFixture {
        let access = PermissionTestAccessController(snapshot: .granted)
        let transports = [transport, resumedTransport].compactMap { $0 }
        let connector = PermissionTestConnector(transports: transports)
        let coordinator = makeCoordinator(connector: connector)
        return PermissionTestFixture(
            model: makeModel(access: access, coordinator: coordinator),
            access: access,
            connector: connector,
            coordinator: coordinator,
            transport: transport
        )
    }

    private func makeCoordinator(
        connector: PermissionTestConnector
    ) -> MicroDeviceCoordinator {
        MicroDeviceCoordinator(
            connector: connector,
            retryDelay: .seconds(30),
            statusTimeout: .seconds(1)
        )
    }

    private func makeModel(
        access: PermissionTestAccessController,
        coordinator: MicroDeviceCoordinator
    ) -> AppModel {
        let model = AppModel(
            configurationStore: temporaryStore(),
            coordinator: coordinator,
            accessController: access,
            initialSystemAccess: access.currentSnapshot
        )
        model.hasStarted = true
        model.isReady = true
        return model
    }

    private func temporaryStore() -> ConfigurationStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return ConfigurationStore(fileURL: directory.appendingPathComponent("configuration.json"))
    }

    private func activateInputState(on model: AppModel) {
        model.pressedControls.insert(.action6)
        _ = model.runtimeRouter.route(
            MicroInputEvent(
                control: .action6,
                phase: .pressed,
                rawActivity: 1,
                agentIndex: nil
            ),
            on: model.selectedLayer
        )
        model.pointerController.update(
            RadialInputEvent(angle: 0, distance: 1),
            configuration: JoystickConfiguration()
        )
    }

    private func releaseActiveControl(on model: AppModel) -> [RoutedCreatorAction] {
        model.runtimeRouter.route(
            MicroInputEvent(
                control: .action6,
                phase: .released,
                rawActivity: 0,
                agentIndex: nil
            ),
            on: model.selectedLayer
        )
    }
}

private struct PermissionTestFixture {
    let model: AppModel
    let access: PermissionTestAccessController
    let connector: PermissionTestConnector
    let coordinator: MicroDeviceCoordinator
    let transport: PermissionTestTransport
}

@MainActor
private final class PermissionTestAccessController: SystemAccessControlling {
    var currentSnapshot: SystemAccessSnapshot

    init(snapshot: SystemAccessSnapshot) {
        currentSnapshot = snapshot
    }

    func snapshot() -> SystemAccessSnapshot { currentSnapshot }
    func requestAccessibility() -> SystemAccessSnapshot { currentSnapshot }
    func requestInputMonitoring() -> SystemAccessSnapshot { currentSnapshot }
    func openPrivacySettings(_ pane: SystemPrivacyPane) {}
}

private actor PermissionTestConnector: MicroTransportConnector {
    private var transports: [any MicroTransport]
    private(set) var connectionAttempts = 0

    init(transport: (any MicroTransport)?) {
        transports = transport.map { [$0] } ?? []
    }

    init(transports: [any MicroTransport]) {
        self.transports = transports
    }

    func connect() async throws -> any MicroTransport {
        connectionAttempts += 1
        guard !transports.isEmpty else { throw MicroConnectionError.deviceNotFound }
        return transports.removeFirst()
    }
}

private actor PermissionTestTransport: MicroTransport {
    nonisolated let kind = MicroTransportKind.usb
    nonisolated let incomingReports: AsyncStream<Data>

    private let continuation: AsyncStream<Data>.Continuation
    private let blockClose: Bool
    private var writes: [Data] = []
    private var closeStarted = false
    private var closeReleased = false
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var closeCount = 0

    init(blockClose: Bool = false) {
        self.blockClose = blockClose
        let stream = AsyncStream<Data>.makeStream()
        incomingReports = stream.stream
        continuation = stream.continuation
    }

    func write(_ report: Data) async throws {
        writes.append(report)
    }

    func close() async {
        closeCount += 1
        closeStarted = true
        if blockClose, !closeReleased {
            await withCheckedContinuation { closeWaiters.append($0) }
        }
        continuation.finish()
    }

    func sendStatus() {
        let payload = Data(#"{"result":{"version":"test","layer_index":1},"id":1}"#.utf8)
        for report in MicroReportFramer.frames(for: payload, transport: kind) {
            continuation.yield(report)
        }
    }

    func releaseClose() {
        closeReleased = true
        let waiters = closeWaiters
        closeWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    func waitForStatusRequest() async throws {
        try await waitUntil { !writes.isEmpty }
    }

    func waitUntilCloseStarted() async throws {
        try await waitUntil { closeStarted }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw PermissionReconciliationTestFailure.timeout
    }
}

@MainActor
private func waitUntilConnected(_ model: AppModel, stage: String = "connection") async throws {
    for _ in 0..<200 {
        if case .connected = model.connectionState { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    XCTFail("Timed out during \(stage): \(model.connectionState)")
    throw PermissionReconciliationTestFailure.timeout
}

@MainActor
private func waitUntilRuntimeStopped(_ model: AppModel) async throws {
    for _ in 0..<200 {
        if model.runtimeTask == nil { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    throw PermissionReconciliationTestFailure.timeout
}

extension SystemAccessSnapshot {
    fileprivate static let granted = Self(accessibility: .granted, inputMonitoring: .granted)
    fileprivate static let deniedForInputMonitoring = Self(
        accessibility: .granted,
        inputMonitoring: .denied
    )
}

private enum PermissionReconciliationTestFailure: Error {
    case timeout
}
