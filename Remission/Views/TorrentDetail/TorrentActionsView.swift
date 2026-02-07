import ComposableArchitecture
import SwiftUI

struct TorrentActionsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        HStack(spacing: 10) {
            AppTorrentActionButton(
                type: isActive ? .pause : .start,
                isBusy: isActive ? store.isPauseLocked : store.isStartLocked,
                isLocked: false,
                action: { store.send(isActive ? .pauseTapped : .startTapped) }
            )

            Divider()
                .frame(height: 18)

            AppTorrentActionButton(
                type: .verify,
                isBusy: store.isVerifyLocked,
                isLocked: false,
                action: { store.send(.verifyTapped) }
            )

            Divider()
                .frame(height: 18)

            AppTorrentActionButton(
                type: .remove,
                isBusy: store.isRemoveLocked,
                isLocked: false,
                action: { store.send(.removeButtonTapped) }
            )
        }
        .padding(.horizontal, 12)
        .frame(height: toolbarPillHeight)
        .background(
            Capsule(style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .accessibilityIdentifier("torrent-actions-inline")
    }

    private var isActive: Bool {
        store.status == 4 || store.status == 6
    }

    private var toolbarPillHeight: CGFloat { 34 }
}

#if DEBUG
    struct TorrentActionsViewPreviewContainer: View {
        var body: some View {
            TorrentActionsView(
                store: Store(
                    initialState: TorrentDetailReducer.State(torrentID: .init(rawValue: 1))
                ) {
                    TorrentDetailReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }

    #Preview {
        TorrentActionsViewPreviewContainer()
            .padding()
    }
#endif
