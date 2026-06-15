import SwiftUI

struct MetaRow: View {
    let label: String
    let value: String
    var valueColor: Color = Theme.cream

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.muted)
            Spacer()
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct ErrorRetryView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(Theme.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again", action: onRetry)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .overlay(Rectangle().stroke(Theme.gold.opacity(0.4), lineWidth: 1))
        }
    }
}
