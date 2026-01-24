import SwiftUI

struct ServerDetailConnectionPill: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions[VerticalAlignment.center]
                }
            Text(L10n.tr("serverDetail.status.connecting"))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .fixedSize(horizontal: true, vertical: false)
        .background(background)
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
        )
        .accessibilityIdentifier("server_detail_status_connecting")
    }

    private var background: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppTheme.Glass.tint(colorScheme)
                            .opacity(colorScheme == .dark ? 0.60 : 0.35),
                        AppTheme.Background.glowColor(colorScheme)
                            .opacity(colorScheme == .dark ? 0.35 : 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.05))
                    .blendMode(.multiply)
            )
            .shadow(
                color: AppTheme.Shadow.card(colorScheme),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}
