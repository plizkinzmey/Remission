import SwiftUI

struct EmptyPlaceholderView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: L10n.tr("%@. %@"),
                locale: Locale.current,
                title,
                message
            )
        )
    }
}

#if DEBUG
    #Preview {
        EmptyPlaceholderView(
            systemImage: "tray",
            title: L10n.tr("placeholder.default.title"),
            message: L10n.tr("placeholder.default.message")
        )
        .padding()
    }
#endif
