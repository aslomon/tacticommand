import CreatorMicroCore
import SwiftUI

struct PointerMoveOptionsView: View {
    let action: Binding<CreatorAction>
    let horizontal: Int
    let vertical: Int

    var body: some View {
        InspectorSection(title: "POINTER NUDGE") {
            axisControl("Horizontal", value: horizontal, binding: horizontalBinding)
            axisControl("Vertical", value: vertical, binding: verticalBinding)
            Text("Positive vertical values move down; each press applies one nudge.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func axisControl(
        _ label: String,
        value: Int,
        binding: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value) px")
                    .font(.system(size: 11, design: .monospaced))
            }
            Slider(value: binding, in: -240...240, step: 1)
        }
    }

    private var horizontalBinding: Binding<Double> {
        Binding(
            get: { Double(horizontal) },
            set: { assign(horizontal: Int($0), vertical: vertical) }
        )
    }

    private var verticalBinding: Binding<Double> {
        Binding(
            get: { Double(vertical) },
            set: { assign(horizontal: horizontal, vertical: Int($0)) }
        )
    }

    private func assign(horizontal: Int, vertical: Int) {
        action.wrappedValue = .pointer(.move(horizontal: horizontal, vertical: vertical))
    }
}
