import ComposableArchitecture
import SwiftUI

struct ServerDetailConnectionCard: View {
    let connectionPhase: ServerConnectionReducer.Phase
    let onRetry: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            connectionContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var connectionContent: some View {
        switch connectionPhase {
        case .idle:
            Text(L10n.tr("serverDetail.status.waiting"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("server_detail_status_idle")

        case .connecting:
            ServerDetailConnectionPill()
                .appMaterialize()

        case .connected:
            EmptyView()

        case .disconnected(let disconnected) where disconnected.attempt < 3:
            ServerDetailConnectionPill()
                .appMaterialize()

        case .disconnected(let disconnected):
            AppStatusCardView(
                systemImage: "wifi.slash",
                title: L10n.tr("serverDetail.status.error"),
                message: disconnected.message,
                buttonTitle: L10n.tr("common.retry"),
                onButtonTap: onRetry,
                iconColor: .orange
            )
            .appMaterialize()
            .accessibilityIdentifier("server_detail_status_offline")

        }
    }
}
