import CreatorMicroCore
import SwiftUI

struct MicroKey: View {
    let control: ControlID
    let model: AppModel
    var width: CGFloat = 68
    var labelOverride: String?

    var body: some View {
        Button {
            model.select(control: control)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: action.actionSymbol)
                    .font(.system(size: 14, weight: .medium))
                Text(labelOverride ?? keyLabel)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
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
            .offset(y: isPressed ? 2 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var action: CreatorAction {
        model.selectedLayer.action(for: control)
    }

    private var isSelected: Bool { model.selectedControl == control }
    private var isPressed: Bool { model.pressedControls.contains(control) }

    private var liveState: KeyActionLiveState? {
        KeyActionLiveState.resolve(
            action: action,
            audio: model.audioSnapshot,
            isDictating: model.isDictating
        )
    }

    private var keyBackground: Color {
        if let liveState { return color(for: liveState.tone).opacity(0.58) }
        if isSelected { return DesignTokens.signal }
        if let index = control.agentIndex,
            model.activeLayer == .agents,
            model.agentSnapshot.slots.indices.contains(index)
        {
            let light = model.agentSnapshot.slots[index].deviceLight
            return Color(creatorMicroHex: light.hex)?.opacity(max(light.brightness, 0.18))
                ?? Color.white.opacity(0.1)
        }
        return Color.white.opacity(isPressed ? 0.22 : 0.1)
    }

    private var borderColor: Color {
        if isSelected { return DesignTokens.signal }
        if let liveState { return color(for: liveState.tone).opacity(0.9) }
        return Color.white.opacity(0.14)
    }

    private var keyForeground: Color {
        liveState == nil && isSelected ? .black : .white.opacity(0.9)
    }

    private var liveStateColor: Color {
        guard let liveState else { return .clear }
        return color(for: liveState.tone)
    }

    private var accessibilityLabel: String {
        let base = "\(control.rawValue), \(action.actionTitle)"
        guard let liveState else { return base }
        return "\(base), \(liveState.label)"
    }

    private func color(for tone: KeyActionStateTone) -> Color {
        switch tone {
        case .failure: DesignTokens.failure
        case .recording: DesignTokens.recording
        case .attention: DesignTokens.attention
        case .signal: DesignTokens.signal
        case .ready: DesignTokens.ready
        case .unavailable: .secondary
        }
    }

    private var keyLabel: String {
        if let index = control.agentIndex,
            model.activeLayer == .agents,
            model.agentSnapshot.slots.indices.contains(index),
            let session = model.agentSnapshot.slots[index].session
        {
            return session.title.uppercased()
        }
        return action.actionTitle.uppercased()
    }
}
