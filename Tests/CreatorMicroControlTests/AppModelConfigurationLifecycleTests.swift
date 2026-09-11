import CreatorMicroCore
import Foundation
import XCTest

@testable import CreatorMicroControl

@MainActor
final class AppModelConfigurationLifecycleTests: XCTestCase {
    func testAutomationMutationsAreRejectedUntilConfigurationIsReady() async {
        let model = AppModel(configurationStore: temporaryStore())
        let handlers = model.makeAutomationHandlers()

        let layerResult = await handlers.setLayerIfReady(.agents)
        let bindingResult = await handlers.resolveBindingIfReady(.action6, layer: .desktop)

        assertLoadingFailure(layerResult)
        assertLoadingFailure(bindingResult)
        XCTAssertEqual(model.activeLayer, .desktop)
    }

    func testAutomationUsesLoadedConfigurationAfterBecomingReady() async throws {
        let store = temporaryStore()
        var expected = MicroConfiguration.default
        expected.assign(action: .openFinder, to: .action6, on: .desktop)
        try await store.save(expected).get()
        let model = AppModel(configurationStore: store)

        await model.loadConfiguration()
        let handlers = model.makeAutomationHandlers()

        try await handlers.setLayerIfReady(.agents).get()
        let binding = try await handlers.resolveBindingIfReady(.action6, layer: .desktop).get()
        XCTAssertEqual(binding, .openFinder)
    }

    func testStartedModelRejectsEditsUntilStoredConfigurationIsLoaded() async throws {
        let store = temporaryStore()
        var expected = MicroConfiguration.default
        expected.assign(action: .openFinder, to: .agent0, on: .desktop)
        expected.microphoneLayout = .linked
        try await store.save(expected).get()
        let model = AppModel(configurationStore: store)
        model.hasStarted = true

        model.assign(.openTerminal, to: .agent0)
        model.setMicrophoneLayout(.separate)
        model.setApplicationRule(bundleIdentifier: "com.example.early", for: .desktop)
        model.setLayerJoystickMode(.off)
        await model.loadConfiguration()

        let storedConfiguration = try await store.load().get()
        XCTAssertEqual(model.configuration, expected)
        XCTAssertEqual(storedConfiguration, expected)
        XCTAssertTrue(model.isReady)
    }

    func testFlushPersistsLatestGeneration() async throws {
        let store = temporaryStore()
        let model = AppModel(configurationStore: store)

        model.assign(.openFinder, to: .agent0)
        model.assign(.openTerminal, to: .agent0)
        await model.flushConfiguration()

        let loaded = try await store.load().get()
        XCTAssertEqual(loaded.layer(.desktop)?.action(for: .agent0), .openTerminal)
    }

    func testFlushPersistsLatestSnapshotWhenPendingSaveWasCancelled() async throws {
        let store = temporaryStore()
        let model = AppModel(configurationStore: store)

        model.assign(.openTerminal, to: .agent0)
        model.configurationSaveTask?.cancel()
        await model.flushConfiguration()

        let loaded = try await store.load().get()
        XCTAssertEqual(loaded.layer(.desktop)?.action(for: .agent0), .openTerminal)
    }

    func testConfigurationMutationPersistsImmediately() async throws {
        let fileURL = temporaryConfigurationURL()
        let model = AppModel(configurationStore: ConfigurationStore(fileURL: fileURL))

        model.assign(.openFinder, to: .agent0)

        let persisted = await waitForConfiguration(at: fileURL) { configuration in
            configuration.layer(.desktop)?.action(for: .agent0) == .openFinder
        }
        model.configurationSaveTask?.cancel()
        XCTAssertTrue(persisted, "The first mutation must be persisted without an intentional wait")
    }

    func testRapidMutationsPersistOnlyTheLatestCompleteConfiguration() async throws {
        let fileURL = temporaryConfigurationURL()
        let model = AppModel(configurationStore: ConfigurationStore(fileURL: fileURL))
        let shortcut = KeyShortcut(
            mainKeys: [
                KeyShortcutKey(key: "j", virtualKeyCode: 38),
                KeyShortcutKey(key: "k", virtualKeyCode: 40),
            ],
            modifiers: [.function, .control]
        )
        let appleDictation = try XCTUnwrap(model.provider(for: .appleDictation))

        model.assign(.openFinder, to: .agent0)
        model.assign(.openTerminal, to: .agent0)
        model.setMicrophoneLayout(.linked)
        model.setApplicationRule(bundleIdentifier: "com.apple.finder", for: .desktop)
        model.setLayerJoystickMode(.pointer)
        model.setLayerJoystickDeadZone(0.2)
        model.setLayerJoystickMaximumSpeed(2_000)
        model.chooseProvider(appleDictation)
        model.setShortcut(shortcut, for: .action10)

        let persisted = await waitForConfiguration(at: fileURL) { configuration in
            let joystick = configuration.resolvedJoystick(for: .desktop)
            let binding = Self.dictationBinding(in: configuration)
            return configuration.layer(.desktop)?.action(for: .agent0) == .openTerminal
                && configuration.microphoneLayout == .linked
                && configuration.applicationLayerRules.contains(
                    ApplicationLayerRule(bundleIdentifier: "com.apple.finder", layer: .desktop)
                )
                && joystick?.mode == .pointer
                && joystick?.deadZone == 0.2
                && joystick?.maximumSpeed == 2_000
                && binding?.providerID == .appleDictation
                && binding?.shortcut == shortcut
        }
        model.configurationSaveTask?.cancel()
        XCTAssertTrue(persisted, "The latest rapid mutation must win after reloading")
    }

    func testRecordedMultiKeyShortcutPersistsImmediatelyAndReloads() async throws {
        let fileURL = temporaryConfigurationURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let model = AppModel(configurationStore: store)
        let shortcut = KeyShortcut(
            mainKeys: [
                KeyShortcutKey(key: "j", virtualKeyCode: 38),
                KeyShortcutKey(key: "k", virtualKeyCode: 40),
            ],
            modifiers: [.function, .control]
        )

        model.setShortcut(shortcut, for: .action10)
        await model.configurationSaveTask?.value

        let reloaded = try await ConfigurationStore(fileURL: fileURL).load().get()
        let action = try XCTUnwrap(reloaded.layer(.desktop)?.action(for: .action10))
        XCTAssertEqual(DictationActionEditor.binding(in: action)?.shortcut, shortcut)
    }

    func testShutdownPersistsShortcutBeforeWaitingForSlowCleanup() async throws {
        let fileURL = temporaryConfigurationURL()
        let store = ConfigurationStore(fileURL: fileURL)
        let model = AppModel(configurationStore: store)
        let cleanupGate = CleanupGate()
        let shortcut = KeyShortcut(
            key: "space",
            modifiers: [.function, .command],
            virtualKeyCode: 49
        )
        model.startupTask = Task { await cleanupGate.wait() }
        model.setShortcut(shortcut, for: .action10)

        let shutdownTask = Task { await model.shutdown() }
        try await Task.sleep(for: .milliseconds(50))

        let reloadResult = await ConfigurationStore(fileURL: fileURL).load()
        await cleanupGate.resume()
        await shutdownTask.value

        let reloaded = try reloadResult.get()
        let action = try XCTUnwrap(reloaded.layer(.desktop)?.action(for: .action10))
        XCTAssertEqual(DictationActionEditor.binding(in: action)?.shortcut, shortcut)
    }

    func testApplyingWorkflowPresetReplacesOnlySelectedSlotAndPersists() async throws {
        let store = temporaryStore()
        let model = AppModel(configurationStore: store)
        let originalDesktop = try XCTUnwrap(model.configuration.layer(.desktop))

        model.applyPreset(.cursor, to: .agents)
        await model.flushConfiguration()

        let stored = try await store.load().get()
        XCTAssertEqual(stored.layer(.desktop), originalDesktop)
        XCTAssertEqual(stored.layer(.agents)?.name, "Cursor")
        XCTAssertEqual(
            stored.layer(.agents)?.action(for: .agent0),
            .keyboardShortcut(KeyShortcut(key: "i", modifiers: [.command], displayName: "Agent"))
        )
    }

    func testRenamingLayerTrimsInputAndPersists() async throws {
        let store = temporaryStore()
        let model = AppModel(configurationStore: store)

        model.renameLayer("  Terminal Flow  ", layer: .codex)
        await model.flushConfiguration()

        let stored = try await store.load().get()
        XCTAssertEqual(stored.layer(.codex)?.name, "Terminal Flow")
    }

    func testRenamingLayerRejectsAnEmptyName() {
        let model = AppModel(configurationStore: temporaryStore())
        let originalName = model.configuration.layer(.desktop)?.name

        model.renameLayer("   ", layer: .desktop)

        XCTAssertEqual(model.configuration.layer(.desktop)?.name, originalName)
    }

    private func temporaryStore() -> ConfigurationStore {
        ConfigurationStore(fileURL: temporaryConfigurationURL())
    }

    private func temporaryConfigurationURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("configuration.json")
    }

    private func waitForConfiguration(
        at fileURL: URL,
        matching predicate: (MicroConfiguration) -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(500))
        while clock.now < deadline {
            if case .success(let configuration) = await ConfigurationStore(fileURL: fileURL).load(),
                predicate(configuration)
            {
                return true
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    private static func dictationBinding(
        in configuration: MicroConfiguration
    ) -> DictationBinding? {
        guard let action = configuration.layer(.desktop)?.action(for: .action10) else {
            return nil
        }
        return DictationActionEditor.binding(in: action)
    }

    private func assertLoadingFailure<T>(
        _ result: Result<T, LocalAutomationHandlerFailure>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failure(let failure) = result else {
            return XCTFail("Expected a loading failure", file: file, line: line)
        }
        XCTAssertTrue(failure.message.localizedCaseInsensitiveContains("loading"))
    }
}

private actor CleanupGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
