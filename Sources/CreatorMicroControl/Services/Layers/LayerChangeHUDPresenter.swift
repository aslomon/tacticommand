import AppKit
import CreatorMicroCore
import SwiftUI

struct LayerChangeHUDPresentation: Equatable {
    let activeLayerName: String
    let nextLayerName: String
    let source: LayerSelectionSource
}

@MainActor
protocol LayerChangeHUDPresenting: AnyObject {
    func show(_ presentation: LayerChangeHUDPresentation)
}

@MainActor
final class LayerChangeHUDPresenter: LayerChangeHUDPresenting {
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?
    private var presentationGeneration: UInt64 = 0

    func show(_ presentation: LayerChangeHUDPresentation) {
        dismissalTask?.cancel()
        presentationGeneration &+= 1
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(
            rootView: LayerChangeHUDView(presentation: presentation)
        )
        position(panel)
        present(panel)
        scheduleDismissal(of: panel, generation: presentationGeneration)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(
                origin: .zero,
                size: NSSize(
                    width: DesignTokens.layerHUDWidth,
                    height: DesignTokens.layerHUDHeight
                )
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSApp.keyWindow?.screen ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = NSPoint(
            x: frame.midX - DesignTokens.layerHUDWidth / 2,
            y: frame.maxY - DesignTokens.layerHUDHeight - 24
        )
        panel.setFrameOrigin(origin)
    }

    private func present(_ panel: NSPanel) {
        if panel.isVisible {
            panel.alphaValue = 1
            return
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 1
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func scheduleDismissal(of panel: NSPanel, generation: UInt64) {
        dismissalTask = Task { [weak self, weak panel] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let self, let panel else { return }
            dismiss(panel, generation: generation)
        }
    }

    private func dismiss(_ panel: NSPanel, generation: UInt64) {
        guard generation == presentationGeneration else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor [weak self, weak panel] in
                guard let self, let panel,
                    generation == presentationGeneration
                else {
                    return
                }
                panel.orderOut(nil)
            }
        }
    }
}

private struct LayerChangeHUDView: View {
    let presentation: LayerChangeHUDPresentation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.3.layers.3d.top.filled")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(DesignTokens.signal)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(presentation.activeLayerName) active")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("Next: \(presentation.nextLayerName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: DesignTokens.layerHUDWidth, height: DesignTokens.layerHUDHeight)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(DesignTokens.signal.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Layer \(presentation.activeLayerName) active. Next layer \(presentation.nextLayerName)."
        )
    }
}
