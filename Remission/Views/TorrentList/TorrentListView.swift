import ComposableArchitecture
import SwiftUI

// swiftlint:disable file_length

#if canImport(UIKit)
    import UIKit
#endif

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>
    @Environment(\.colorScheme) var themeColorScheme

    var body: some View {
        #if os(macOS)
            container
                .toolbar {
                    if store.connectionEnvironment != nil {
                        ToolbarItem(placement: .principal) {
                            macOSToolbarControls
                        }
                    }
                }
                .confirmationDialog(
                    $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
                )
                .alert(
                    $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
                )
        #else
            ZStack {
                if shouldShowSearchBar {
                    container
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
                } else {
                    container
                }

                if store.visibleItems.isEmpty && store.phase == .loaded {
                    TorrentListEmptyStateView()
                        .allowsHitTesting(false)
                }
            }
            .refreshable {
                store.send(.refreshRequested)
                // Ждем завершения обновления (сброса флага), игнорируя долгоживущие эффекты (поллинг)
                while store.isRefreshing {
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            .background(AppBackgroundView())
            .alert(
                $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
            )
        #endif
    }
}

extension TorrentListView {
    @ViewBuilder
    private var container: some View {
        #if os(macOS)
            AppFooterLayout {
                VStack(alignment: .leading, spacing: 12) {
                    TorrentListHeaderView(title: L10n.tr("torrentList.section.title"))

                    if store.isRefreshing && store.isAwaitingConnection == false {
                        refreshIndicator
                            .padding(.vertical, 2)
                    }

                    if let banner = store.errorPresenter.banner {
                        ErrorBannerView(
                            message: banner.message,
                            onRetry: banner.retry == nil
                                ? nil
                                : { store.send(.errorPresenter(.bannerRetryTapped)) },
                            onDismiss: { store.send(.errorPresenter(.bannerDismissed)) }
                        )
                        .padding(.bottom, 6)
                    }

                    if let offline = store.offlineState {
                        offlineBanner(offline)
                            .padding(Edge.Set.bottom, 4)
                    }

                    TorrentListControlsView(store: store)

                    macOSScrollableContent
                        .frame(maxWidth: .infinity, alignment: .top)

                    if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                        Text(L10n.tr("torrentList.autorefresh.disabled"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            } footer: {
                footerBar
            }
        #else
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let banner = store.errorPresenter.banner {
                        ErrorBannerView(
                            message: banner.message,
                            onRetry: banner.retry == nil
                                ? nil
                                : { store.send(.errorPresenter(.bannerRetryTapped)) },
                            onDismiss: { store.send(.errorPresenter(.bannerDismissed)) }
                        )
                        .padding(.bottom, 6)
                    }

                    if let offline = store.offlineState {
                        offlineBanner(offline)
                            .padding(.bottom, 4)
                    }

                    Group {
                        content
                    }
                    .redacted(reason: store.isRefreshing ? .placeholder : [])
                    .disabled(store.isRefreshing)

                    if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                        Text(L10n.tr("torrentList.autorefresh.disabled"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .top) {
                TorrentListHeaderiOSView(store: store)
                    .padding(.horizontal, 8)
                    .background(
                        BlurView(style: .regular)
                            .ignoresSafeArea(edges: .top)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .black, location: 0.98),
                                        .init(color: .black.opacity(0), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .ignoresSafeArea(edges: .top)
                            )
                    )
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        #endif
    }

    #if os(macOS)
        @ViewBuilder
        private var macOSScrollableContent: some View {
            if store.connectionEnvironment == nil && store.isAwaitingConnection == false,
                store.items.isEmpty,
                case .idle = store.phase
            {
                disconnectedView
            } else {
                switch store.phase {
                case .idle:
                    if store.isAwaitingConnection {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(0..<6, id: \.self) { index in
                                    TorrentRowSkeletonView(index: index)
                                        .padding(.vertical, 10)
                                        .appCardSurface(cornerRadius: 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        EmptyView()
                    }

                case .loading:
                    if store.isRefreshing == false {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(0..<6, id: \.self) { index in
                                    TorrentRowSkeletonView(index: index)
                                        .padding(.vertical, 10)
                                        .appCardSurface(cornerRadius: 14)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                case .loaded, .offline:
                    if store.visibleItems.isEmpty {
                        if case .offline(let offline) = store.phase {
                            offlineView(message: offline.message)
                        } else {
                            TorrentListEmptyStateView()
                        }
                    } else {
                        ScrollView {
                            torrentRowsMacOS
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                case .error(let message):
                    errorView(message: message)
                }
            }
        }
    #endif

    @ViewBuilder
    private var content: some View {
        if store.connectionEnvironment == nil && store.isAwaitingConnection == false,
            store.items.isEmpty,
            case .idle = store.phase
        {
            disconnectedView
        } else {
            switch store.phase {
            case .idle:
                if store.isAwaitingConnection {
                    loadingView
                } else {
                    EmptyView()
                }

            case .loading:
                if store.isRefreshing == false {
                    loadingView
                }

            case .loaded, .offline:
                if store.visibleItems.isEmpty {
                    if case .offline(let offline) = store.phase {
                        offlineView(message: offline.message)
                    } else {
                        Color.clear
                    }
                } else {
                    #if os(macOS)
                        torrentRowsMacOS
                    #else
                        torrentRows
                    #endif
                }
            case .error(let message):
                errorView(message: message)
            }
        }
    }

    private var loadingView: some View {
        ForEach(0..<6, id: \.self) { index in
            TorrentRowSkeletonView(index: index)
                .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
        .accessibilityIdentifier("torrent_list_loading")
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("torrentList.state.noConnection.title"))
                .font(.subheadline)
                .bold()
            Text(L10n.tr("torrentList.state.noConnection.message"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func offlineBanner(_ offline: TorrentListReducer.OfflineState) -> some View {
        HStack(spacing: 8) {
            Label(L10n.tr("torrentList.state.noConnection.title"), systemImage: "wifi.slash")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let timestamp = offline.lastUpdatedAt {
                Text(timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func offlineView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.tr("torrentList.state.noConnection.title"), systemImage: "wifi.slash")
                .foregroundStyle(.orange)
            Text(message.isEmpty ? L10n.tr("torrentList.state.noConnection.message") : message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(L10n.tr("common.retry")) {
                store.send(.refreshRequested)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("torrent_list_offline_retry")
        }
        .padding(.vertical, 8)
    }

    private var footerBar: some View {
        AppFooterInfoBar(
            leftText: storageSummaryText,
            centerText: AppVersion.footerText,
            rightText: transmissionVersionText
        )
        .accessibilityIdentifier("torrent_list_footer")
    }

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

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.tr("torrentList.error.title"), systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
            Text(message.isEmpty ? L10n.tr("torrentList.error.message.default") : message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(L10n.tr("common.retry")) {
                store.send(.refreshRequested)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("torrent_list_error_retry")
        }
        .padding(.vertical, 8)
    }

    private var torrentRows: some View {
        ForEach(store.visibleItems, id: \.id) { item in
            torrentRow(item)
        }
        .id(store.itemsRevision)
    }

    @ViewBuilder
    private func torrentRow(_ item: TorrentListItem.State) -> some View {
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

    private func displayItem(for item: TorrentListItem.State) -> TorrentListItem.State {
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
        private func torrentRowIOS(
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
        private func torrentRowMacOS(
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
        private var torrentRowsMacOS: some View {
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

    private func rowBackground(for item: TorrentListItem.State) -> some View {
        TorrentRowBackgroundView(isIsolated: item.torrent.status == .isolated)
    }

    private func rowActions(
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

    private func isRemoveCommand(_ command: TorrentListReducer.TorrentCommand?) -> Bool {
        guard let command else { return false }
        if case .remove = command {
            return true
        }
        return false
    }

    private var refreshIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(L10n.tr("torrentList.refresh.progress"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("torrent_list_refresh_indicator")
    }

    private var longestStatusTitle: String {
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

    private struct TorrentStatusData {
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

#if os(iOS)
    struct BlurView: UIViewRepresentable {
        let style: UIBlurEffect.Style

        func makeUIView(context: Context) -> UIVisualEffectView {
            let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
            return view
        }

        func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
#endif

#if DEBUG
    #Preview("Loaded list") {
        TorrentListView(store: .preview(state: .previewLoaded()))
    }
#endif

// swiftlint:enable file_length
