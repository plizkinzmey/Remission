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
        connectionContent
    }

    @ViewBuilder
    private var connectionContent: some View {
        if let banner = errorPresenter.banner {
            ErrorBannerView(
                message: banner.message,
                onRetry: banner.retry == nil
                    ? nil
                    : { onRetryError(banner.retry!) },
                onDismiss: { onDismissError() }
            )
        }
        switch connectionState.phase {
        case .idle:
            Text(L10n.tr("serverDetail.status.waiting"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("server_detail_status_idle")

        case .connecting:
            HStack {
                Spacer(minLength: 0)
                ServerDetailConnectionPill()
                Spacer(minLength: 0)
            }

        case .ready:
            EmptyView()

        case .offline(let offline):
            Label(
                L10n.tr("serverDetail.status.error"),
                systemImage: "wifi.slash"
            )
            .foregroundStyle(.orange)
            Text(offline.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(L10n.tr("common.retry")) {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("server_detail_status_offline")

        case .failed(let failure):
            Label(L10n.tr("serverDetail.status.error"), systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
            Text(failure.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(L10n.tr("serverDetail.action.retry")) {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("server_detail_status_failed")
            .accessibilityHint(L10n.tr("serverDetail.action.retry"))
        }
    }
}
