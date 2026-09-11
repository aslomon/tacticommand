import CreatorMicroCore
import Foundation
import Observation

@Observable
@MainActor
final class AppModel {
    var configuration: MicroConfiguration = .default
    var layerSelection = LayerSelectionState(active: .desktop)
    var selectedControl: ControlID = .action10
    var connectionState: DeviceConnectionState = .disconnected
    var deviceStatus: DeviceStatus?
    var providers: [DictationProviderDefinition] = []
    var agentSnapshot = AgentSlotSnapshot.empty
    var pressedControls: Set<ControlID> = []
    var systemAccess: SystemAccessSnapshot
    var launchAtLoginEnabled: Bool
    var isDictating = false
    var audioSnapshot = SystemAudioSnapshot.unavailable
    var automationSocketPath: String?
    var frontmostApplicationBundleIdentifier: String?
    var detectedDevices: [MicroDeviceRecord] = []
    var knownDevices: [MicroDeviceRecord] = []
    var lastError: String?
    var isReady = false

    @ObservationIgnored let configurationStore: ConfigurationStore
    @ObservationIgnored let providerRegistry: DictationProviderRegistry<WorkspaceInstalledApplicationCatalog>
    @ObservationIgnored let coordinator: MicroDeviceCoordinator
    @ObservationIgnored let actionExecutor: CreatorActionExecutor
    @ObservationIgnored let audioMonitor: SystemAudioMonitor
    @ObservationIgnored let agentStore: AgentSlotStore
    @ObservationIgnored let pointerController: JoystickPointerController
    @ObservationIgnored let arrowKeyController: JoystickArrowKeyController
    @ObservationIgnored let accessController: any SystemAccessControlling
    @ObservationIgnored let loginController: LaunchAtLoginController
    @ObservationIgnored let frontmostApplicationMonitor: FrontmostApplicationMonitor
    @ObservationIgnored let deviceInventory: any MicroDeviceInventoryReading
    @ObservationIgnored let recentDeviceStore: any RecentMicroDeviceStoring
    @ObservationIgnored var runtimeRouter: MicroRuntimeRouter
    @ObservationIgnored var shortOrLongPressState = ShortOrLongPressStateMachine()
    @ObservationIgnored var longPressTasks: [ControlID: Task<Void, Never>] = [:]
    @ObservationIgnored var startupTask: Task<Void, Never>?
    @ObservationIgnored var runtimeTask: Task<Void, Never>?
    @ObservationIgnored var joystickRuntimeTask: Task<Void, Never>?
    @ObservationIgnored var joystickRadialRestartTask: Task<Void, Never>?
    @ObservationIgnored var joystickSafetyRuntimeTask: Task<Void, Never>?
    @ObservationIgnored var reconnectTask: Task<Void, Never>?
    @ObservationIgnored var systemAccessReconciliationTask: Task<Void, Never>?
    @ObservationIgnored var systemAccessGeneration: UInt64 = 0
    @ObservationIgnored var lastDeviceDiagnostic: String?
    @ObservationIgnored var agentTask: Task<Void, Never>?
    @ObservationIgnored var automationServer: LocalAutomationServer?
    @ObservationIgnored var automationServerStartTask: Task<Void, Never>?
    @ObservationIgnored var applicationMonitorTask: Task<Void, Never>?
    @ObservationIgnored var audioMonitorTask: Task<Void, Never>?
    @ObservationIgnored var configurationSaveTask: Task<Void, Never>?
    @ObservationIgnored var configurationGeneration: UInt64 = 0
    @ObservationIgnored var applicationLayerSession = ApplicationLayerSession.inactive
    @ObservationIgnored var layerChangePresenter: (any LayerChangeHUDPresenting)?
    @ObservationIgnored var lastRadialInput: RadialInputEvent?
    @ObservationIgnored var joystickRadialGeneration: UInt64 = 0
    @ObservationIgnored var joystickRequiresNeutral = false
    @ObservationIgnored var joystickConnectionSequence: UInt64?
    @ObservationIgnored var isJoystickConnectionVerified = false
    @ObservationIgnored var joystickReconnectBoundaryPending = false
    @ObservationIgnored var isTerminating = false
    @ObservationIgnored var hasStarted = false

    init(
        configurationStore: ConfigurationStore = ConfigurationStore(),
        applicationCatalog: WorkspaceInstalledApplicationCatalog = WorkspaceInstalledApplicationCatalog(),
        coordinator: MicroDeviceCoordinator? = nil,
        accessController: (any SystemAccessControlling)? = nil,
        initialSystemAccess: SystemAccessSnapshot? = nil,
        arrowKeyController: JoystickArrowKeyController? = nil,
        deviceInventory: any MicroDeviceInventoryReading = IOKitMicroDeviceInventory(),
        recentDeviceStore: any RecentMicroDeviceStoring = UserDefaultsRecentMicroDeviceStore()
    ) {
        let accessController = accessController ?? SystemAccessController()
        let loginController = LaunchAtLoginController()
        let audioController = SystemAudioController()
        self.configurationStore = configurationStore
        providerRegistry = DictationProviderRegistry(catalog: applicationCatalog)
        self.coordinator =
            coordinator
            ?? MicroDeviceCoordinator(connector: IOKitMicroTransportConnector())
        actionExecutor = CreatorActionExecutor(audio: audioController)
        audioMonitor = SystemAudioMonitor(audio: audioController)
        agentStore = AgentSlotStore(adapters: AgentAdapterFactory.makeDefault())
        pointerController = JoystickPointerController()
        self.arrowKeyController = arrowKeyController ?? JoystickArrowKeyController()
        self.accessController = accessController
        self.loginController = loginController
        frontmostApplicationMonitor = FrontmostApplicationMonitor()
        self.deviceInventory = deviceInventory
        self.recentDeviceStore = recentDeviceStore
        knownDevices = recentDeviceStore.load()
        runtimeRouter = MicroRuntimeRouter(microphoneLayout: .separate)
        systemAccess = initialSystemAccess ?? accessController.snapshot()
        launchAtLoginEnabled = loginController.isEnabled
        providers = Self.initialProviders
        pointerController.onFailure = { [weak self] failure in
            Task { @MainActor [weak self] in
                self?.handleSystemEventFailure(failure)
            }
        }
        self.arrowKeyController.onFailure = { [weak self] failure in
            Task { @MainActor [weak self] in
                self?.handleSystemEventFailure(failure)
            }
        }
    }

    var selectedLayer: LayerConfiguration {
        configuration.layer(activeLayer)
            ?? LayerConfiguration(id: activeLayer, name: "Layer \(activeLayer.displayPosition)")
    }

    var activeLayer: LayerIndex { layerSelection.active }

    var canMutateConfiguration: Bool { !hasStarted || isReady }

    var selectedAction: CreatorAction {
        selectedLayer.action(for: selectedControl)
    }

    var currentDictationBinding: DictationBinding? {
        dictationBinding(for: .action10)
    }

    var isInputMuted: Bool {
        audioSnapshot.inputMute == .muted
    }

    var isOutputMuted: Bool {
        audioSnapshot.outputMute == .muted
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startAudioMonitoring()
        startupTask = Task { [weak self] in
            guard let self else { return }
            await loadConfiguration()
            guard !Task.isCancelled else { return }
            startRuntime()
            startAgentRefresh()
            startApplicationLayerMonitoring()
            startAutomationServer()
            await refreshProviders()
        }
    }

    func select(
        layer: LayerIndex,
        source: LayerSelectionSource = .editor
    ) {
        recordManualLayerOverrideIfNeeded(source: source)
        let layerChanged = layer != activeLayer
        if layerChanged {
            resetJoystickLocalBoundary()
            releaseShortOrLongPressesForLayerChange()
        }
        layerSelection.select(layer, source: source)
        if layerChanged {
            refreshLightingAfterLayerChange()
            presentLayerChange(source: source)
        }
    }

    func apply(
        layer command: LayerCommand,
        source: LayerSelectionSource
    ) {
        select(layer: command.destination(from: activeLayer), source: source)
    }

    func select(control: ControlID) {
        selectedControl = control
    }

    func assign(_ action: CreatorAction, to control: ControlID? = nil) {
        guard canMutateConfiguration else { return }
        configuration.assign(
            action: action,
            to: control ?? selectedControl,
            on: activeLayer
        )
        saveConfiguration()
    }

    func setMicrophoneLayout(_ layout: MicrophoneLayout) {
        guard canMutateConfiguration else { return }
        releaseActiveMicrophoneActions()
        configuration.microphoneLayout = layout
        runtimeRouter = MicroRuntimeRouter(microphoneLayout: layout)
        saveConfiguration()
    }

    func clearLastError() {
        lastError = nil
        lastDeviceDiagnostic = nil
    }

    private func presentLayerChange(source: LayerSelectionSource) {
        let activeName =
            configuration.layer(activeLayer)?.name
            ?? "Layer \(activeLayer.displayPosition)"
        let nextLayer = LayerCommand.next.destination(from: activeLayer)
        let nextName =
            configuration.layer(nextLayer)?.name
            ?? "Layer \(nextLayer.displayPosition)"
        layerChangePresenter?.show(
            LayerChangeHUDPresentation(
                activeLayerName: activeName,
                nextLayerName: nextName,
                source: source
            )
        )
    }

    private static var initialProviders: [DictationProviderDefinition] {
        BuiltInDictationProvider.allCases.map {
            $0.definition(availability: .notInstalled)
        }
    }
}

extension AgentSlotSnapshot {
    fileprivate static var empty: AgentSlotSnapshot {
        AgentSlotSnapshot(
            slots: AgentSlotID.allCases.map { AgentSlot(id: $0, session: nil) },
            adapterAvailability: [:]
        )
    }
}
