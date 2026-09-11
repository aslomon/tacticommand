import AppKit
import CreatorMicroCore
import SwiftUI

struct LayerChangeHUDPresentation: Equatable {
    let activeLayerName: String
    let nextLayerName: String
    let source: LayerSelectionSource
}

struct LayerChangeHUDContent: Equatable {
    let eyebrow = "ACTIVE LAYER"
    let activeLayerName: String
    let nextLayerLabel: String
    let sourceLabel: String
    let accessibilityLabel: String

    init(presentation: LayerChangeHUDPresentation) {
        activeLayerName = presentation.activeLayerName
        nextLayerLabel = "NEXT · \(presentation.nextLayerName.uppercased())"
        sourceLabel = Self.sourceLabel(for: presentation.source)
        accessibilityLabel =
            "Layer \(presentation.activeLayerName) active. "
            + "Next layer \(presentation.nextLayerName). "
            + "Selected by \(Self.accessibilitySource(for: presentation.source))."
    }

    private static func sourceLabel(for source: LayerSelectionSource) -> String {
        switch source {
        case .launchDefault: "DEFAULT"
        case .editor: "EDITOR"
        case .physicalKey: "KEY"
        case .applicationRule: "APP RULE"
        case .automation: "AUTOMATION"
        }
    }

    private static func accessibilitySource(for source: LayerSelectionSource) -> String {
        switch source {
        case .launchDefault: "the default"
        case .editor: "the editor"
        case .physicalKey: "key"
        case .applicationRule: "an app rule"
        case .automation: "automation"
        }
    }
}

enum LayerChangeHUDBrandMark {
    static let dotCount = 4
    static let columns = 2
    static let rows = dotCount / columns
}

@MainActor
protocol LayerChangeHUDPresenting: AnyObject {
    func show(_ presentation: LayerChangeHUDPresentation)
}

@MainActor
protocol LayerChangeHUDAccessibilityAnnouncing: AnyObject {
    func announce(_ message: String)
}

@MainActor
private final class AppKitLayerChangeHUDAccessibilityAnnouncer:
    LayerChangeHUDAccessibilityAnnouncing
{
    func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}

@MainActor
final class LayerChangeHUDPresenter: LayerChangeHUDPresenting {
    private let accessibilityAnnouncer: any LayerChangeHUDAccessibilityAnnouncing
    private var panel: NSPanel?
    private var dismissalTask: Task<Void, Never>?
    private var presentationGeneration: UInt64 = 0

    init(
        accessibilityAnnouncer: any LayerChangeHUDAccessibilityAnnouncing =
            AppKitLayerChangeHUDAccessibilityAnnouncer()
    ) {
        self.accessibilityAnnouncer = accessibilityAnnouncer
    }

    func show(_ presentation: LayerChangeHUDPresentation) {
        dismissalTask?.cancel()
        presentationGeneration &+= 1
        let panel = panel ?? makePanel()
        panel.contentView = NSHostingView(
            rootView: LayerChangeHUDView(presentation: presentation)
        )
        position(panel)
        present(panel)
        accessibilityAnnouncer.announce(
            LayerChangeHUDContent(presentation: presentation).accessibilityLabel
        )
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

    private var content: LayerChangeHUDContent {
        LayerChangeHUDContent(presentation: presentation)
    }

    var body: some View {
        HStack(spacing: 12) {
            LayerChangeHUDFourDotMark()
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(DesignTokens.signal)
                        .frame(width: 5, height: 5)
                    Text(content.eyebrow)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(content.sourceLabel)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(content.activeLayerName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(content.nextLayerLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .frame(width: DesignTokens.layerHUDWidth, height: DesignTokens.layerHUDHeight)
        .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.accessibilityLabel)
    }
}

private struct LayerChangeHUDFourDotMark: View {
    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<LayerChangeHUDBrandMark.rows, id: \.self) { _ in
                dotRow
            }
        }
        .padding(9)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var dotRow: some View {
        HStack(spacing: 5) {
            ForEach(0..<LayerChangeHUDBrandMark.columns, id: \.self) { _ in
                Circle()
                    .fill(Color.primary.opacity(0.88))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
