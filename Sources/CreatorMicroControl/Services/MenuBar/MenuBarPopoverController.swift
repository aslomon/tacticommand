import AppKit
import SwiftUI

@MainActor
final class MenuBarPopoverController: NSObject {
    static let statusItemSymbolName = "circle.grid.2x2.fill"

    private let statusItem: NSStatusItem
    private let popover: NSPopover

    init(model: AppModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        configureStatusItem()
        configurePopover(model: model)
    }

    func dismantle() {
        popover.performClose(nil)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: Self.statusItemSymbolName,
            accessibilityDescription: AppIdentity.displayName
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = AppIdentity.displayName
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp])
    }

    private func configurePopover(model: AppModel) {
        let rootView = MenuBarRootView(model: model)
        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        hostingController.sizingOptions = [.preferredContentSize]
        hostingController.preferredContentSize = NSSize(
            width: DesignTokens.popoverWidth,
            height: hostingController.view.fittingSize.height
        )
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        if MenuBarPopoverPresentationPolicy.activatesApplicationOnOpen {
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        configurePresentedWindow()
    }

    private func configurePresentedWindow() {
        guard let window = popover.contentViewController?.view.window else { return }
        if MenuBarPopoverPresentationPolicy.makesWindowOpaque {
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true
        }
        window.makeKey()
    }
}
