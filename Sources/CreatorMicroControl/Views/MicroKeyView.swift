import CreatorMicroCore
import SwiftUI

struct MicroKey: View {
    let control: ControlID
    let model: AppModel
    var width: CGFloat = 68
    var labelOverride: String?
    /// Set when this key's physical cap is shared with another `ControlID` on the
    /// connected device (e.g. Creator's wide action10/action11 switch). Purely
    /// presentational: the other control's saved binding is never touched here.
    var physicallySharedWith: ControlID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            model.select(control: control)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: action.actionSymbol)
                    .font(.system(size: 14, weight: .medium))
                Text(labelOverride ?? keyLabel)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                if let liveState {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(liveStateColor)
                            .frame(width: 5, height: 5)
                        Text(liveState.compactLabel)
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                }
            }
            .foregroundStyle(keyForeground)
            .frame(width: width, height: 54)
            .background(keyBackground, in: RoundedRectangle(cornerRadius: DesignTokens.keyRadius))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.keyRadius)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .bottom) { lightBar }
            .offset(y: pressOffset)
            .opacity(pressCrossfadeOpacity)
            .animation(.easeOut(duration: 0.11), value: isPressed)
            .animation(.easeOut(duration: 0.18), value: isSelected)
            .animation(.easeOut(duration: 0.18), value: appearance)
        }
        .buttonStyle(.plain)
        .help(tooltipText)
        .accessibilityLabel(accessibilityLabel)
    }

    private var action: CreatorAction {
        model.selectedLayer.action(for: control)
    }

    private var isSelected: Bool { model.selectedControl == control }
    private var isPressed: Bool {
        model.pressedControls.contains(control)
            || physicallySharedWith.map { model.pressedControls.contains($0) } == true
    }

    /// Physical press moves the key 2 pt; Reduce Motion drops the displacement
    /// and relies on `pressCrossfadeOpacity` instead.
    private var pressOffset: CGFloat {
        reduceMotion ? 0 : (isPressed ? 2 : 0)
    }

    private var pressCrossfadeOpacity: Double {
        reduceMotion && isPressed ? 0.7 : 1
    }

    /// Exact device appearance for this key — the same color/brightness/effect/speed
    /// `AppModel` sends to the hardware (observed signal > agent status > resting
    /// function-category color > nil for unassigned/no signal). Single source of truth
    /// for interior fill, border tint, and the light bar; never re-derived locally.
    private var appearance: LightingKeyAppearance? {
        model.keyAppearance(for: control)
    }

    /// Text-only presentation (e.g. "MUTED", "62%"). Its color comes from `appearance`.
    private var liveState: KeyActionLiveState? {
        KeyActionLiveState.resolve(
            action: action,
            audio: model.audioSnapshot,
            isDictating: model.isDictating
        )
    }

    private var keyBackground: Color {
        guard let appearance else {
            return isSelected ? DesignTokens.signalSoft : Color.white.opacity(0.1)
        }
        return Color(rgb: appearance.color).opacity(clampedBrightness(appearance) * 0.4)
    }

    private var borderColor: Color {
        if isSelected { return DesignTokens.signal }
        guard let appearance else { return Color.white.opacity(0.14) }
        return Color(rgb: appearance.color).opacity(0.9)
    }

    private var keyForeground: Color {
        appearance == nil && isSelected ? DesignTokens.signal : .white.opacity(0.9)
    }

    private var liveStateColor: Color {
        guard let appearance else { return .clear }
        return Color(rgb: appearance.color)
    }

    /// Narrow signature light bar: the per-key hardware diagnostic, mirroring
    /// the pad canvas ambient zone described in DESIGN.md "Signature detail". Carries
    /// the exact device color at its real brightness, so it reads as luminous for any
    /// bound function and stays neutral/dim only when the key is truly unassigned.
    private var lightBar: some View {
        Capsule()
            .fill(lightBarColor)
            .frame(width: max(width - 20, 24), height: 2)
            .padding(.bottom, 3)
            .opacity(lightBarOpacity)
    }

    private var lightBarColor: Color {
        guard let appearance else {
            return isSelected ? DesignTokens.signal : Color.white.opacity(0.16)
        }
        return Color(rgb: appearance.color)
    }

    private var lightBarOpacity: Double {
        guard let appearance else { return 1 }
        return clampedBrightness(appearance)
    }

    private func clampedBrightness(_ appearance: LightingKeyAppearance) -> Double {
        min(max(appearance.brightness, 0), 1)
    }

    private var accessibilityLabel: String {
        var base = "\(control.rawValue), \(action.actionTitle)"
        if let liveState { base += ", \(liveState.label)" }
        if let physicallySharedWith {
            base += ", physically shares one key with \(physicallySharedWith.rawValue)"
        }
        return base
    }

    private var tooltipText: String {
        var base = agentSessionTitle ?? labelOverride ?? action.actionTitle
        if let physicallySharedWith {
            base += " — shares one physical key with \(physicallySharedWith.rawValue)"
        }
        return base
    }

    private var keyLabel: String {
        if let agentSessionTitle { return agentSessionTitle.uppercased() }
        return action.compactActionTitle
    }

    private var agentSessionTitle: String? {
        guard let index = control.agentIndex,
            MicroKeyPresentationPolicy.showsAgentSession(
                for: control,
                activeLayer: model.activeLayer
            ),
            model.agentSnapshot.slots.indices.contains(index)
        else { return nil }
        return model.agentSnapshot.slots[index].session?.title
    }
}

enum MicroKeyPresentationPolicy {
    static func showsAgentSession(
        for control: ControlID,
        activeLayer: LayerIndex
    ) -> Bool {
        control.agentIndex != nil && activeLayer == .agentFocus
    }
}
