import ComposableArchitecture
import SwiftUI

struct TorrentActionsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        HStack(spacing: 10) {
            iconButton(
                title: isActive
                    ? L10n.tr("torrentDetail.actions.pause")
                    : L10n.tr("torrentDetail.actions.start"),
                systemImage: isActive ? "pause.fill" : "play.fill",
                tint: isActive ? .orange : .green,
                accessibilityIdentifier: isActive ? "torrent-action-pause" : "torrent-action-start",
                lockCategory: isActive ? .pause : .start
            ) {
                store.send(isActive ? .pauseTapped : .startTapped)
            }

            Divider()
                .frame(height: 18)

            iconButton(
                title: L10n.tr("torrentDetail.actions.verify"),
                systemImage: "checkmark.shield.fill",
                tint: .blue,
                accessibilityIdentifier: "torrent-action-verify",
                lockCategory: .verify
            ) {
                store.send(.verifyTapped)
            }

            Divider()
                .frame(height: 18)

            iconButton(
                title: L10n.tr("torrentDetail.actions.remove"),
                systemImage: "trash.fill",
                tint: .red,
                accessibilityIdentifier: "torrent-action-remove",
                lockCategory: .remove
            ) {
                store.send(.removeButtonTapped)
            }
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

    private func iconButton(
        title: String,
        systemImage: String,
        tint: Color,
        accessibilityIdentifier: String,
        lockCategory: TorrentDetailReducer.CommandCategory? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let isBusy = lockCategory.map(isLocked(for:)) ?? false
        let button = Button(action: action) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .opacity(isBusy ? 0 : 1)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .tint(tint)
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .disabled(isBusy)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
        .accessibilityHint(L10n.tr("torrentDetail.actions.hint"))
        .animation(.easeInOut(duration: 0.2), value: isBusy)
        #if os(macOS)
            return button.help(title)
        #else
            return button
        #endif
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
