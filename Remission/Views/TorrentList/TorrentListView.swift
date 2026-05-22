import ComposableArchitecture
import SwiftUI

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        ZStack {
            nativeList

            if let unavailableState {
                unavailableView(unavailableState)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(unavailableState.retryIdentifier != nil)
            }
        }
        .navigationTitle(L10n.tr("torrentList.section.title"))
        .searchable(
            text: .init(
                get: { store.searchQuery },
                set: { store.send(.searchQueryChanged($0)) }
            ),
            placement: .automatic,
            prompt: Text(L10n.tr("torrentList.search.prompt"))
        ) {
            ForEach(store.searchSuggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .searchCompletion(suggestion)
            }
        }
        .refreshable {
            store.send(.refreshRequested)
            while store.isRefreshing {
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        .toolbar {
            if store.connectionEnvironment != nil {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        store.send(.refreshRequested)
                    } label: {
                        Label(L10n.tr("common.retry"), systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isRefreshing)
                    .accessibilityIdentifier("torrentlist_refresh_button")
                }
            }
        }
        .confirmationDialog(
            $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
        )
        .alert(
            $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
        )
        #if os(macOS)
            .safeAreaInset(edge: .bottom) {
                footerBar
            }
        #endif
    }
}

private struct TorrentListUnavailableState: Equatable {
    var title: String
    var message: String
    var systemImage: String
    var retryIdentifier: String?
}

extension TorrentListView {
    private var nativeList: some View {
        List {
            if let banner = store.errorPresenter.banner {
                Section {
                    ErrorBannerView(
                        message: banner.message,
                        onRetry: banner.retry == nil
                            ? nil
                            : { store.send(.errorPresenter(.bannerRetryTapped)) },
                        onDismiss: { store.send(.errorPresenter(.bannerDismissed)) }
                    )
                }
            }

            if let offline = store.offlineState {
                Section {
                    offlineBanner(offline)
                }
            }

            if store.connectionEnvironment != nil {
                Section {
                    TorrentListControlsView(store: store)
                    #if os(iOS)
                        TorrentListStorageSummaryView(summary: store.storageSummary)
                    #endif
                }
            }

            listContentSection

            if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                Section {
                    Label(
                        L10n.tr("torrentList.autorefresh.disabled"),
                        systemImage: "pause.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                }
            }
        }
        .listStyle(.inset)
        .accessibilityIdentifier("torrent_list")
    }

    @ViewBuilder
    private var listContentSection: some View {
        switch store.phase {
        case .idle:
            if store.isAwaitingConnection {
                loadingSection
            }
        case .loading:
            if store.isRefreshing == false {
                loadingSection
            }
        case .loaded, .offline:
            if store.visibleItems.isEmpty == false {
                torrentRows
            }
        case .error:
            EmptyView()
        }
    }

    private var loadingSection: some View {
        Section {
            ForEach(0..<6, id: \.self) { index in
                TorrentRowSkeletonView(index: index)
                    .accessibilityIdentifier("torrent_list_loading_row_\(index)")
            }
        }
        .accessibilityIdentifier("torrent_list_loading")
    }

    private var unavailableState: TorrentListUnavailableState? {
        if store.connectionEnvironment == nil && store.isAwaitingConnection == false,
            store.items.isEmpty,
            case .idle = store.phase
        {
            return TorrentListUnavailableState(
                title: L10n.tr("torrentList.state.noConnection.title"),
                message: L10n.tr("torrentList.state.noConnection.message"),
                systemImage: "bolt.horizontal.circle"
            )
        }

        switch store.phase {
        case .idle, .loading:
            return nil
        case .loaded:
            guard store.visibleItems.isEmpty else { return nil }
            return TorrentListUnavailableState(
                title: L10n.tr("torrentList.empty.title"),
                message: L10n.tr("torrentList.empty.message"),
                systemImage: "tray"
            )
        case .offline(let offline):
            guard store.visibleItems.isEmpty else { return nil }
            return TorrentListUnavailableState(
                title: L10n.tr("torrentList.state.noConnection.title"),
                message: offline.message.isEmpty
                    ? L10n.tr("torrentList.state.noConnection.message")
                    : offline.message,
                systemImage: "wifi.slash",
                retryIdentifier: "torrent_list_offline_retry"
            )
        case .error(let message):
            return TorrentListUnavailableState(
                title: L10n.tr("torrentList.error.title"),
                message: message.isEmpty
                    ? L10n.tr("torrentList.error.message.default")
                    : message,
                systemImage: "exclamationmark.circle",
                retryIdentifier: "torrent_list_error_retry"
            )
        }
    }

    private func unavailableView(_ state: TorrentListUnavailableState) -> some View {
        ContentUnavailableView {
            Label(state.title, systemImage: state.systemImage)
        } description: {
            Text(state.message)
        } actions: {
            if let retryIdentifier = state.retryIdentifier {
                Button(L10n.tr("common.retry")) {
                    store.send(.refreshRequested)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(retryIdentifier)
            }
        }
    }

    private func offlineBanner(_ offline: TorrentListReducer.OfflineState) -> some View {
        HStack(spacing: 8) {
            Label(L10n.tr("torrentList.state.noConnection.title"), systemImage: "wifi.slash")
            if let timestamp = offline.lastUpdatedAt {
                Text(timestamp, style: .relative)
                    .monospacedDigit()
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var torrentRows: some View {
        Section {
            ForEach(store.visibleItems.map(displayItem(for:))) { item in
                torrentRow(item)
            }
        }
        .id(store.itemsRevision)
    }

    private func torrentRow(_ item: TorrentListItem.State) -> some View {
        let actions = rowActions(for: item)
        return TorrentRowView(
            item: item,
            openRequested: { store.send(.rowTapped(item.id)) },
            actions: actions,
            isLocked: item.isRemoving
        )
        .equatable()
        .transaction { $0.animation = nil }
        .opacity(item.isRemoving ? 0.6 : 1)
        .disabled(item.isRemoving)
        .accessibilityIdentifier("torrent_list_item_\(item.id.rawValue)")
        .contextMenu {
            rowCommands(actions)
        }
        #if os(iOS)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if let actions, actions.isLocked == false {
                    Button(role: .destructive) {
                        actions.onRemove()
                    } label: {
                        Label(L10n.tr("torrentDetail.actions.remove"), systemImage: "trash")
                    }
                    .disabled(actions.isRemoveBusy)

                    Button {
                        actions.onVerify()
                    } label: {
                        Label(L10n.tr("torrentDetail.actions.verify"), systemImage: "shield")
                    }
                    .disabled(actions.isVerifyBusy)
                    .tint(.blue)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if let actions, actions.isLocked == false {
                    Button {
                        actions.onStartPause()
                    } label: {
                        Label(
                            actions.isActive
                                ? L10n.tr("torrentDetail.actions.pause")
                                : L10n.tr("torrentDetail.actions.start"),
                            systemImage: actions.isActive ? "pause.fill" : "play.fill"
                        )
                    }
                    .disabled(actions.isStartPauseBusy)
                    .tint(actions.isActive ? .orange : .green)
                }
            }
        #endif
    }

    @ViewBuilder
    private func rowCommands(_ actions: TorrentRowView.RowActions?) -> some View {
        if let actions, actions.isLocked == false {
            Button {
                actions.onStartPause()
            } label: {
                Label(
                    actions.isActive
                        ? L10n.tr("torrentDetail.actions.pause")
                        : L10n.tr("torrentDetail.actions.start"),
                    systemImage: actions.isActive ? "pause.fill" : "play.fill"
                )
            }
            .disabled(actions.isStartPauseBusy)

            Button {
                actions.onVerify()
            } label: {
                Label(L10n.tr("torrentDetail.actions.verify"), systemImage: "shield")
            }
            .disabled(actions.isVerifyBusy)

            Button(role: .destructive) {
                actions.onRemove()
            } label: {
                Label(L10n.tr("torrentDetail.actions.remove"), systemImage: "trash")
            }
            .disabled(actions.isRemoveBusy)
        }
    }

    private func displayItem(for item: TorrentListItem.State) -> TorrentListItem.State {
        guard store.verifyPendingIDs.contains(item.id) else { return item }
        guard item.torrent.status != .checking, item.torrent.status != .checkWaiting else {
            return item
        }
        var copy = item
        copy.torrent.status = .checkWaiting
        return copy
    }

    private func rowActions(for item: TorrentListItem.State) -> TorrentRowView.RowActions? {
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

    private func isRemoveCommand(_ command: TorrentListReducer.TorrentCommand?) -> Bool {
        guard let command else { return false }
        if case .remove = command {
            return true
        }
        return false
    }

    #if os(macOS)
        private var footerBar: some View {
            HStack(spacing: 12) {
                Text(storageSummaryText ?? " ")
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(AppVersion.footerText)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(transmissionVersionText ?? " ")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
            .accessibilityIdentifier("torrent_list_footer")
        }
    #endif

    private var storageSummaryText: String? {
        guard let summary = store.storageSummary else { return nil }
        let total = StorageFormatters.bytes(summary.totalBytes)
        let free = StorageFormatters.bytes(summary.freeBytes)
        return String(format: L10n.tr("storage.summary.short"), total, free)
    }

    private var transmissionVersionText: String? {
        guard let handshake = store.handshake else { return nil }
        let description = handshake.serverVersionDescription?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let versionText: String
        if let description, description.isEmpty == false {
            versionText = description
        } else {
            versionText = String(
                format: L10n.tr("serverDetail.status.rpcVersion"),
                Int64(handshake.rpcVersion)
            )
        }
        return "\(L10n.tr("serverList.transmissionVersionLabel")) \(versionText)"
    }
}

#if DEBUG
    #Preview("Loaded list") {
        TorrentListView(store: .preview(state: .previewLoaded()))
    }
#endif
