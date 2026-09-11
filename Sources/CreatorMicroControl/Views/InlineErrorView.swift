import SwiftUI

struct InlineErrorView: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.failure)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss error")
        }
        .padding(10)
        .background(
            DesignTokens.failure.opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: DesignTokens.panelRadius,
                style: .continuous
            ))
    }
}
