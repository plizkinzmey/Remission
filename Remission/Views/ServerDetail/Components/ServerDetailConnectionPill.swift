import SwiftUI

struct ServerDetailConnectionPill: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(L10n.tr("serverDetail.status.connecting"))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .fixedSize(horizontal: true, vertical: false)
        .appPillSurface()
        .accessibilityIdentifier("server_detail_status_connecting")
    }
}
