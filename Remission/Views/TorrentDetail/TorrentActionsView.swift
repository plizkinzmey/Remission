import ComposableArchitecture
import SwiftUI

struct TorrentActionsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    actionButton(
                        title: isActive
                            ? L10n.tr("torrentDetail.actions.pause")
                            : L10n.tr("torrentDetail.actions.start"),
                        systemImage: isActive ? "pause.fill" : "play.fill",
                        color: isActive ? .orange : .green,
                        lockCategory: isActive ? .pause : .start
                    ) {
                        store.send(isActive ? .pauseTapped : .startTapped)
                    }

                    actionButton(
                        title: L10n.tr("torrentDetail.actions.verify"),
                        systemImage: "checkmark.shield.fill",
                        color: .blue,
                        lockCategory: .verify
                    ) {
                        store.send(.verifyTapped)
                    }
                }

                actionButton(
                    title: L10n.tr("torrentDetail.actions.remove"),
                    systemImage: "trash.fill",
                    color: .red,
                    fullWidth: true,
                    lockCategory: .remove
                ) {
                    store.send(.removeButtonTapped)
                }
            }
        } label: {
            Text(L10n.tr("torrentDetail.actions.title"))
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-actions-section")
    }

    private var isActive: Bool {
        store.status == 4 || store.status == 6
    }

    private func actionButton(
        title: String,
        systemImage: String,
        color: Color,
        fullWidth: Bool = false,
        lockCategory: TorrentDetailReducer.CommandCategory? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .disabled(lockCategory.map(isLocked(for:)) ?? false)
        .accessibilityIdentifier(identifier(for: title))
        .accessibilityLabel(title)
        .accessibilityHint(L10n.tr("torrentDetail.actions.hint"))
    }

    private func identifier(for title: String) -> String {
        switch title {
        case L10n.tr("torrentDetail.actions.pause"):
            return "torrent-action-pause"
        case L10n.tr("torrentDetail.actions.start"):
            return "torrent-action-start"
        case L10n.tr("torrentDetail.actions.verify"):
            return "torrent-action-verify"
        case L10n.tr("torrentDetail.actions.remove"):
            return "torrent-action-remove"
        default:
            return "torrent-action-\(title.lowercased())"
        }
    }

    private func isLocked(for category: TorrentDetailReducer.CommandCategory) -> Bool {
        store.withState { $0.isCommandCategoryLocked(category) }
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
