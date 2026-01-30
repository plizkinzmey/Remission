import ComposableArchitecture
import SwiftUI

struct ServerDetailConnectionCard: View {
    let connectionState: ServerDetailReducer.ConnectionState
    let errorPresenter: ErrorPresenter<ServerDetailReducer.ErrorRetry>.State
    let onRetry: () -> Void
    let onDismissError: () -> Void
    let onRetryError: (ServerDetailReducer.ErrorRetry) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            connectionContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var connectionContent: some View {
        switch connectionState.phase {
        case .idle:
            Text(L10n.tr("serverDetail.status.waiting"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("server_detail_status_idle")

        case .connecting:
            ServerDetailConnectionPill()

        case .ready:
            EmptyView()

        case .offline(let offline):
            AppStatusCardView(
                systemImage: "wifi.slash",
                title: L10n.tr("serverDetail.status.error"),
                message: offline.message,
                buttonTitle: L10n.tr("common.retry"),
                onButtonTap: onRetry,
                iconColor: .orange
            )
            .accessibilityIdentifier("server_detail_status_offline")

        case .failed(let failure):
            AppStatusCardView(
                systemImage: "xmark.octagon.fill",
                title: L10n.tr("serverDetail.status.error"),
                message: failure.message,
                buttonTitle: L10n.tr("serverDetail.action.retry"),
                onButtonTap: onRetry,
                iconColor: .red
            )
            .accessibilityIdentifier("server_detail_status_failed")
        }
    }
}
