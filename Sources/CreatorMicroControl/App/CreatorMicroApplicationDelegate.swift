import AppKit

@MainActor
final class CreatorMicroApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel? {
        didSet { model?.layerChangePresenter = layerChangeHUDPresenter }
    }
    private var terminationPolicy = ApplicationTerminationPolicy()
    private let shutdown = BoundedShutdown(timeout: .seconds(1))
    private let layerChangeHUDPresenter = LayerChangeHUDPresenter()
    private var menuBarPopoverController: MenuBarPopoverController?
    private var isObservingWorkspaceActivation = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        startObservingWorkspaceActivation()
        if let model {
            menuBarPopoverController = MenuBarPopoverController(model: model)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshSystemAccess()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopObservingWorkspaceActivation()
        menuBarPopoverController?.dismantle()
        menuBarPopoverController = nil
    }

    func applicationShouldTerminate(
        _ sender: NSApplication
    ) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        model.prepareForTermination()
        guard terminationPolicy.request() == .beginCleanup else {
            return .terminateNow
        }
        Task {
            _ = await shutdown.run {
                await model.shutdown()
            }
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func workspaceApplicationDidActivate(_ notification: Notification) {
        model?.refreshSystemAccess()
    }

    private func startObservingWorkspaceActivation() {
        guard !isObservingWorkspaceActivation else { return }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceApplicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared
        )
        isObservingWorkspaceActivation = true
    }

    private func stopObservingWorkspaceActivation() {
        guard isObservingWorkspaceActivation else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: NSWorkspace.shared
        )
        isObservingWorkspaceActivation = false
    }

}
