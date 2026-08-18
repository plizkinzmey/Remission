import ComposableArchitecture
import SwiftUI

extension TorrentListView {
    @ViewBuilder
    func torrentRow(_ item: TorrentListItem.State) -> some View {
        let displayItem = displayItem(for: item)
        let actions = rowActions(for: displayItem)
        let statusColor = TorrentStatusData(status: displayItem.torrent.status).color
        let row = TorrentRowView(
            item: displayItem,
            openRequested: { store.send(.rowTapped(item.id)) },
            actions: actions,
            longestStatusTitle: longestStatusTitle,
            isLocked: item.isRemoving
        )
        #if os(iOS)
            torrentRowIOS(
                item: item,
                row: row,
                statusColor: statusColor,
                actions: actions
            )
        #else
            torrentRowMacOS(
                item: item,
                row: row,
                statusColor: statusColor
            )
        #endif
    }

    func displayItem(for item: TorrentListItem.State) -> TorrentListItem.State {
        guard store.verifyPendingIDs.contains(item.id) else { return item }
        // Optimistically show "check waiting" in the UI until the backend reports check start.
        // This avoids flicker when Transmission temporarily reports intermediate statuses.
        guard item.torrent.status != .checking, item.torrent.status != .checkWaiting else {
            return item
        }
        var copy = item
        copy.torrent.status = .checkWaiting
        return copy
    }

    #if os(iOS)
        @ViewBuilder
        func torrentRowIOS(
            item: TorrentListItem.State,
            row: TorrentRowView,
            statusColor: Color,
            actions: TorrentRowView.RowActions?
        ) -> some View {
            let baseRow =
                row
                .transaction { $0.animation = nil }
                .accessibilityIdentifier("torrent_list_item_\(item.id.rawValue)")
                .opacity(item.isRemoving ? 0.6 : 1)
                .disabled(item.isRemoving)
                .padding(.horizontal, 0)
                .padding(.vertical, 10)
                .appListRowSurface(color: statusColor)
                .contentShape(
                    .contextMenuPreview,
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .contextMenu {
                    if let actions, actions.isLocked == false {
                        Button(
                            actions.isActive
                                ? L10n.tr("torrentDetail.actions.pause")
                                : L10n.tr("torrentDetail.actions.start")
                        ) {
                            actions.onStartPause()
                        }
                        .disabled(actions.isStartPauseBusy)
                        Button(L10n.tr("torrentDetail.actions.verify")) {
                            actions.onVerify()
                        }
                        .disabled(actions.isVerifyBusy)
                        Button(L10n.tr("torrentDetail.actions.remove"), role: .destructive) {
                            actions.onRemove()
                        }
                        .disabled(actions.isRemoveBusy)
                    }
                }
            if store.pendingRemoveTorrentID == item.id {
                baseRow.confirmationDialog(
                    $store.scope(
                        state: \.removeConfirmation,
                        action: \.removeConfirmation
                    )
                )
            } else {
                baseRow
            }
        }
    #else
        func torrentRowMacOS(
            item: TorrentListItem.State,
            row: TorrentRowView,
            statusColor: Color
        ) -> some View {
            row
                .equatable()
                .transaction { $0.animation = nil }
                .accessibilityIdentifier("torrent_list_item_\(item.id.rawValue)")
                .opacity(item.isRemoving ? 0.6 : 1)
                .disabled(item.isRemoving)
                .padding(.vertical, 10)
                .appListRowSurface(color: statusColor)
                .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(rowBackground(for: item))
        }
    #endif

    #if os(macOS)
        var torrentRowsMacOS: some View {
            LazyVStack(spacing: 10) {
                // On macOS we render from a cached `visibleItems` list for performance.
                // Map through `displayItem(for:)` so optimistic verify state (checkWaiting + busy) is
                // reflected immediately and consistently across platforms.
                ForEach(store.visibleItems.map(displayItem(for:))) { item in
                    TorrentRowView(
                        item: item,
                        openRequested: { store.send(.rowTapped(item.id)) },
                        actions: rowActions(for: item),
                        longestStatusTitle: longestStatusTitle,
                        isLocked: item.isRemoving
                    )
                    .equatable()
                    .transaction { $0.animation = nil }
                    .padding(.vertical, 10)
                    .appListRowSurface(
                        color: TorrentStatusData(status: item.torrent.status).color
                    )
                    .opacity(item.isRemoving ? 0.6 : 1)
                    .disabled(item.isRemoving)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    #endif

    func rowBackground(for item: TorrentListItem.State) -> some View {
        TorrentRowBackgroundView(isIsolated: item.torrent.status == .isolated)
    }

    func rowActions(
        for item: TorrentListItem.State
    ) -> TorrentRowView.RowActions? {
        guard store.connectionEnvironment != nil else { return nil }
        let isActive = item.torrent.status == .downloading || item.torrent.status == .seeding
        let inFlightCommand = store.inFlightCommands[item.id]?.command
        let isChecking = item.torrent.status == .checking || item.torrent.status == .checkWaiting
        let isStartPauseBusy = inFlightCommand == (isActive ? .pause : .start)
        let isVerifyBusy =
            store.verifyPendingIDs.contains(item.id) || inFlightCommand == .verify || isChecking
        let isRemoveBusy = item.isRemoving || isRemoveCommand(inFlightCommand)

        return TorrentRowView.RowActions(
            isActive: isActive,
            isLocked: item.isRemoving,
            isStartPauseBusy: isStartPauseBusy,
            isVerifyBusy: isVerifyBusy,
            isRemoveBusy: isRemoveBusy,
            onStartPause: {
                store.send(isActive ? .pauseTapped(item.id) : .startTapped(item.id))
            },
            onVerify: {
                store.send(.verifyTapped(item.id))
            },
            onRemove: {
                store.send(.removeTapped(item.id))
            }
        )
    }

    func isRemoveCommand(_ command: TorrentListReducer.TorrentCommand?) -> Bool {
        guard let command else { return false }
        if case .remove = command {
            return true
        }
        return false
    }

    var refreshIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(L10n.tr("torrentList.refresh.progress"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("torrent_list_refresh_indicator")
    }

    var longestStatusTitle: String {
        let titles = [
            L10n.tr("torrentList.status.paused"),
            L10n.tr("torrentList.status.checkWaiting"),
            L10n.tr("torrentList.status.checking"),
            L10n.tr("torrentList.status.downloadWaiting"),
            L10n.tr("torrentList.status.downloading"),
            L10n.tr("torrentList.status.seedWaiting"),
            L10n.tr("torrentList.status.seeding"),
            L10n.tr("torrentList.status.error")
        ]
        return titles.max(by: { $0.count < $1.count }) ?? ""
    }

    struct TorrentStatusData {
        let color: Color

        init(status: Torrent.Status) {
            switch status {
            case .stopped: color = .secondary
            case .checkWaiting, .checking: color = .orange
            case .downloadWaiting, .seedWaiting: color = .indigo
            case .downloading: color = .blue
            case .seeding: color = .green
            case .isolated: color = .red
            }
        }
    }
}
