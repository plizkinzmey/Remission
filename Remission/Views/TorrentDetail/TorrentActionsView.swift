import ComposableArchitecture
import SwiftUI

struct TorrentActionsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        HStack(spacing: 10) {
            AppTorrentActionButton(
                type: isActive ? .pause : .start,
                isBusy: isBusy(for: isActive ? .pause : .start),
                isLocked: false,
                action: { store.send(isActive ? .pauseTapped : .startTapped) }
            )

            Divider()
                .frame(height: 18)

            AppTorrentActionButton(
                type: .verify,
                isBusy: isBusy(for: .verify),
                isLocked: false,
                action: { store.send(.verifyTapped) }
            )

            Divider()
                .frame(height: 18)

            AppTorrentActionButton(
                type: .remove,
                isBusy: isBusy(for: .remove),
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

    private func isBusy(for type: TorrentActionType) -> Bool {
        let category: TorrentDetailReducer.CommandCategory
        switch type {
        case .start: category = .start
        case .pause: category = .pause
        case .verify: category = .verify
        case .remove: category = .remove
        }
        return store.withState { $0.isCommandCategoryLocked(category) }
    }
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
