import ComposableArchitecture
// swiftlint:disable file_length
import SwiftUI

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>
    @State private var searchText: String = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            #if os(macOS)
                container
                    .toolbar {
                        if store.connectionEnvironment != nil {
                            ToolbarItem(placement: .principal) {
                                macOSToolbarControls
                            }
                        }
                    }
            #else
                if shouldShowSearchBar {
                    container
                        .searchable(
                            text: $searchText,
                            placement: .automatic,
                            prompt: Text(L10n.tr("torrentList.search.prompt"))
                        ) {
                            ForEach(searchSuggestions, id: \.self) { suggestion in
                                Text(suggestion)
                                    .searchCompletion(suggestion)
                            }
                        }
                } else {
                    container
                }
            #endif
        }
        #if os(iOS)
            .refreshable {
                await store.send(.refreshRequested).finish()
            }
        #endif
        .onAppear {
            if searchText != store.searchQuery {
                searchText = store.searchQuery
            }
        }
        .onDisappear {
            searchTask?.cancel()
            searchTask = nil
        }
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            guard newValue != store.searchQuery else { return }
            searchTask = Task { @MainActor in
                guard Task.isCancelled == false else { return }
                await store.send(.searchQueryChanged(newValue)).finish()
            }
        }
        .onChange(of: store.searchQuery) { _, newValue in
            guard newValue != searchText else { return }
            searchText = newValue
        }
        .alert(
            $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
        )
    }
}

extension TorrentListView {
    #if os(macOS)
        private var macOSToolbarControls: some View {
            HStack(spacing: 10) {
                Button {
                    store.send(.addTorrentButtonTapped)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("torrentlist_add_button")

                Divider()
                    .frame(height: 18)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .imageScale(.medium)
                        .foregroundStyle(.secondary)
                    TextField(
                        L10n.tr("torrentList.search.prompt"),
                        text: $searchText
                    )
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.primary)
                }
                .accessibilityIdentifier("torrentlist_search_field")
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 300, idealWidth: 420, maxWidth: 520)
            .frame(height: macOSToolbarPillHeight)
            .appToolbarPillSurface()
        }
    #endif

    #if os(macOS)
        private var macOSToolbarPillHeight: CGFloat { 34 }
        private var macOSSortPickerWidth: CGFloat { 150 }
    #endif

    #if os(iOS)
        private var shouldShowSearchBar: Bool {
            store.connectionEnvironment != nil && store.visibleItems.isEmpty == false
        }
    #endif
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

    @ViewBuilder
    private var container: some View {
        #if os(macOS)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Spacer(minLength: 0)
                    Text(L10n.tr("torrentList.section.title"))
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("torrent_list_header")
                    Spacer(minLength: 0)
                }

                if store.isRefreshing {
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
                        .padding(.bottom, 4)
                }

                controls

                macOSScrollableContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                    Text(L10n.tr("torrentList.autorefresh.disabled"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #else
            if shouldCenterEmptyState {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.tr("torrentList.section.title"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("torrent_list_header")
                        .allowsHitTesting(false)

                    if store.isRefreshing {
                        refreshIndicator
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
                            .padding(.bottom, 4)
                    }

                    storageSummaryView
                        .frame(maxWidth: .infinity, alignment: .center)

                    controls

                    Spacer(minLength: 0)

                    emptyStateView

                    Spacer(minLength: 0)

                    if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                        Text(L10n.tr("torrentList.autorefresh.disabled"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("torrentList.section.title"))
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("torrent_list_header")
                            .allowsHitTesting(false)

                        if store.isRefreshing {
                            refreshIndicator
                        }

                        content

                        if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                            Text(L10n.tr("torrentList.autorefresh.disabled"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        #endif
    }

    #if os(iOS)
        private var shouldCenterEmptyState: Bool {
            guard store.connectionEnvironment != nil else { return false }
            if case .loaded = store.phase {
                return store.visibleItems.isEmpty
            }
            return false
        }
    #endif

    #if os(macOS)
        @ViewBuilder
        private var macOSScrollableContent: some View {
            if store.connectionEnvironment == nil && store.items.isEmpty {
                disconnectedView
            } else {
                switch store.phase {
                case .idle:
                    EmptyView()

                case .loading:
                    if store.isRefreshing == false {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(0..<placeholderCount, id: \.self) { index in
                                    TorrentRowSkeletonView(index: index)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .appCardSurface(cornerRadius: 14)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }

                case .loaded, .offline:
                    if store.visibleItems.isEmpty {
                        if case .offline(let offline) = store.phase {
                            offlineView(message: offline.message)
                        } else {
                            emptyStateView
                        }
                    } else {
                        ScrollView {
                            torrentRowsMacOS
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
        if store.connectionEnvironment == nil && store.items.isEmpty {
            disconnectedView
        } else {
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
            storageSummaryView
                .frame(maxWidth: .infinity, alignment: .center)
            #if !os(macOS)
                controls
            #endif

            switch store.phase {
            case .idle:
                EmptyView()

            case .loading:
                if store.isRefreshing == false {
                    loadingView
                }

            case .loaded, .offline:
                if store.visibleItems.isEmpty {
                    if case .offline(let offline) = store.phase {
                        offlineView(message: offline.message)
                    } else {
                        emptyStateView
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

    private var searchSuggestions: [String] {
        let query = store.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return Array(
            store.visibleItems
                .map(\.torrent.name)
                .filter { name in
                    guard query.isEmpty == false else { return true }
                    return name.localizedCaseInsensitiveContains(query) == false
                }
                .prefix(5)
        )
    }

    private var loadingView: some View {
        ForEach(0..<placeholderCount, id: \.self) { index in
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

    private func offlineBanner(_ offline: TorrentListReducer.State.OfflineState) -> some View {
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

    @ViewBuilder
    private var storageSummaryView: some View {
        if let summary = store.storageSummary {
            let total = StorageFormatters.bytes(summary.totalBytes)
            let free = StorageFormatters.bytes(summary.freeBytes)
            Label(
                String(format: L10n.tr("storage.summary"), total, free),
                systemImage: "externaldrive.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            #if os(macOS)
                .frame(height: macOSToolbarPillHeight)
            #else
                .frame(height: 34)
            #endif
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
            .accessibilityIdentifier("torrent_list_storage_summary")
        }
    }

    private var emptyStateView: some View {
        #if os(macOS)
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.secondary)

                Text(L10n.tr("torrentList.empty.title"))
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityIdentifier("torrent_list_empty_state")
        #else
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("torrentList.empty.title"))
                    .font(.subheadline)
                    .bold()
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityIdentifier("torrent_list_empty_state")
        #endif
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
        ForEach(store.visibleItems) { item in
            let actions = rowActions(for: item)
            TorrentRowView(
                item: item,
                openRequested: { store.send(.rowTapped(item.id)) },
                actions: actions,
                longestStatusTitle: longestStatusTitle
            )
            .accessibilityIdentifier("torrent_list_item_\(item.id.rawValue)")
            #if os(iOS)
                .padding(.horizontal, 0)
                .padding(.vertical, 10)
                .appCardSurface(cornerRadius: 14)
                .contentShape(
                    .contextMenuPreview,
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            #else
                .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(rowBackground(for: item))
            #endif
            #if os(iOS)
                .contextMenu {
                    if let actions {
                        Button(
                            actions.isActive
                                ? L10n.tr("torrentDetail.actions.pause")
                                : L10n.tr("torrentDetail.actions.start")
                        ) {
                            actions.onStartPause()
                        }
                        Button(L10n.tr("torrentDetail.actions.verify")) {
                            actions.onVerify()
                        }
                        Button(L10n.tr("torrentDetail.actions.remove"), role: .destructive) {
                            actions.onRemove()
                        }
                    }
                }
            #endif
        }
    }

    #if os(macOS)
        private var torrentRowsMacOS: some View {
            LazyVStack(spacing: 10) {
                ForEach(store.visibleItems) { item in
                    TorrentRowView(
                        item: item,
                        openRequested: { store.send(.rowTapped(item.id)) },
                        actions: rowActions(for: item),
                        longestStatusTitle: longestStatusTitle
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .appCardSurface(cornerRadius: 14)
                }
            }
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

        return TorrentRowView.RowActions(
            isActive: isActive,
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

    private var controls: some View {
        #if os(macOS)
            VStack(alignment: .leading, spacing: 12) {
                filterAndSortRowMacOS
            }
            .padding(.vertical, 4)
        #else
            VStack(alignment: .leading, spacing: 12) {
                filterSegmentedControl
                if store.visibleItems.isEmpty == false {
                    HStack {
                        sortPicker
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.vertical, 4)
        #endif
    }

    #if os(macOS)
        private var filterAndSortRowMacOS: some View {
            ZStack {
                filterSegmentedControl
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 12) {
                    if store.storageSummary != nil {
                        storageSummaryView
                    }

                    Spacer(minLength: 0)

                    sortPicker
                        .labelsHidden()
                }
            }
        }
    #endif

    private var filterSegmentedControl: some View {
        Picker(
            L10n.tr("torrentList.filter.title"),
            selection: Binding(
                get: { store.selectedFilter },
                set: { store.send(.filterChanged($0)) }
            )
        ) {
            ForEach(TorrentListReducer.Filter.allCases, id: \.self) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .accessibilityIdentifier("torrentlist_filter_picker")
        .pickerStyle(.segmented)
        .foregroundStyle(.primary)
        #if os(macOS)
            .controlSize(.large)
        #endif
    }

    private var sortPicker: some View {
        #if os(macOS)
            Menu {
                ForEach(TorrentListReducer.SortOrder.allCases, id: \.self) { sort in
                    Button(sort.title) {
                        store.send(.sortChanged(sort))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(store.sortOrder.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .frame(width: macOSSortPickerWidth, height: macOSToolbarPillHeight)
                .contentShape(Rectangle())
                .appToolbarPillSurface()
            }
            .accessibilityIdentifier("torrentlist_sort_picker")
            .buttonStyle(.plain)
        #else
            Picker(
                L10n.tr("torrentList.sort.title"),
                selection: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.sortChanged($0)) }
                )
            ) {
                ForEach(TorrentListReducer.SortOrder.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .accessibilityIdentifier("torrentlist_sort_picker")
            .pickerStyle(.menu)
        #endif
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
}

private struct TorrentRowView: View {
    var item: TorrentListItem.State
    var openRequested: (() -> Void)?
    var actions: RowActions?
    var longestStatusTitle: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    if let openRequested {
                        Button(action: openRequested) {
                            Text(item.torrent.name)
                                .font(.headline)
                                .lineLimit(2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
                    } else {
                        Text(item.torrent.name)
                            .font(.headline)
                            .lineLimit(2)
                            .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    #if os(macOS)
                        if let actions {
                            actionsPill(actions)
                        }
                    #endif
                    statusBadge
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)

            ProgressView(value: item.metrics.progressFraction)
                .tint(progressColor)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")
                .accessibilityValue(item.metrics.progressText)

            #if os(iOS)
                HStack(spacing: 12) {
                    Label(
                        peersText,
                        systemImage: "person.2"
                    )
                    .font(.caption)
                    .foregroundStyle(.primary)

                    Spacer(minLength: 6)

                    Label(item.metrics.speedSummary, systemImage: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .layoutPriority(1)
                        .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
                }
            #else
                HStack(spacing: 12) {
                    Label(item.metrics.progressText, systemImage: "circle.dashed")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("torrent_row_progress_\(item.torrent.id.rawValue)")

                    if let etaText = item.metrics.etaText {
                        Label(etaText, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }

                    Label(
                        peersText,
                        systemImage: "person.2"
                    )
                    .font(.caption)
                    .foregroundStyle(.primary)

                    Spacer(minLength: 6)

                    Label(item.metrics.speedSummary, systemImage: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
                }
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("torrent_row_\(item.torrent.id.rawValue)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.tr("%@, %@, %@, %@"),
                locale: Locale.current,
                item.torrent.name,
                statusTitle,
                item.metrics.progressText,
                item.metrics.speedSummary
            )
        )
        #if !os(macOS)
            .accessibilityHint(L10n.tr("Open torrent details"))
        #endif
    }

    struct RowActions {
        var isActive: Bool
        var onStartPause: () -> Void
        var onVerify: () -> Void
        var onRemove: () -> Void
    }

    private func actionsPill(_ actions: RowActions) -> some View {
        HStack(spacing: 10) {
            pillIconButton(
                systemImage: actions.isActive ? "pause.fill" : "play.fill",
                accessibilityLabel: actions.isActive
                    ? L10n.tr("torrentDetail.actions.pause")
                    : L10n.tr("torrentDetail.actions.start"),
                tint: actions.isActive ? .orange : .green,
                action: actions.onStartPause
            )

            Divider()
                .frame(height: 18)

            pillIconButton(
                systemImage: "checkmark.shield.fill",
                accessibilityLabel: L10n.tr("torrentDetail.actions.verify"),
                tint: .blue,
                action: actions.onVerify
            )

            Divider()
                .frame(height: 18)

            pillIconButton(
                systemImage: "trash.fill",
                accessibilityLabel: L10n.tr("torrentDetail.actions.remove"),
                tint: .red,
                action: actions.onRemove
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .appPillSurface()
        #if !os(visionOS)
            .appGlassEffectTransition(.materialize)
        #endif
        .accessibilityIdentifier("torrent_row_actions_\(item.id.rawValue)")
    }

    private func pillIconButton(
        systemImage: String,
        accessibilityLabel: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .accessibilityLabel(accessibilityLabel)
        #if os(macOS)
            .help(accessibilityLabel)
        #endif
    }

    private var peersText: String {
        "\(item.torrent.summary.peers.connected) peers"
    }

    private var statusBadge: some View {
        ZStack {
            Text(statusAbbreviation)
                .font(.subheadline.weight(.semibold))
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(statusColor.opacity(0.15))
        )
        .overlay(
            Circle()
                .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
        )
        .foregroundStyle(statusColor)
        .accessibilityIdentifier("torrent_list_item_status_\(item.id.rawValue)")
        .accessibilityLabel(statusTitle)
    }

    private var statusAbbreviation: String {
        switch item.torrent.status {
        case .stopped:
            return L10n.tr("torrentList.status.abbrev.paused")
        case .checkWaiting, .checking:
            return L10n.tr("torrentList.status.abbrev.checking")
        case .downloadWaiting, .seedWaiting:
            return L10n.tr("torrentList.status.abbrev.waiting")
        case .downloading:
            return L10n.tr("torrentList.status.abbrev.downloading")
        case .seeding:
            return L10n.tr("torrentList.status.abbrev.seeding")
        case .isolated:
            return L10n.tr("torrentList.status.abbrev.error")
        }
    }

    private var statusTitle: String {
        switch item.torrent.status {
        case .stopped: return L10n.tr("torrentList.status.paused")
        case .checkWaiting: return L10n.tr("torrentList.status.checkWaiting")
        case .checking: return L10n.tr("torrentList.status.checking")
        case .downloadWaiting: return L10n.tr("torrentList.status.downloadWaiting")
        case .downloading: return L10n.tr("torrentList.status.downloading")
        case .seedWaiting: return L10n.tr("torrentList.status.seedWaiting")
        case .seeding: return L10n.tr("torrentList.status.seeding")
        case .isolated: return L10n.tr("torrentList.status.error")
        }
    }

    private var statusColor: Color {
        switch item.torrent.status {
        case .downloading: return .blue
        case .seeding: return .green
        case .stopped: return .primary
        case .checking, .checkWaiting: return .orange
        case .downloadWaiting, .seedWaiting: return .purple
        case .isolated: return .red
        }
    }

    private var progressColor: Color {
        statusColor
    }
}

private struct TorrentRowBackgroundView: View {
    let isIsolated: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let fillColor: Color =
            isIsolated
            ? Color.red.opacity(0.08)
            : Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.06)
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(fillColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
    }
}

private struct TorrentRowSkeletonView: View {
    var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 16)
                Spacer(minLength: 20)
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 72, height: 16)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 8)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
                .frame(height: 8)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.08))
                .frame(height: 6)
        }
        .padding(.vertical, 6)
        .redacted(reason: .placeholder)
        .accessibilityIdentifier("torrent_row_skeleton_\(index)")
    }
}

private let placeholderCount = 6

#Preview("Loaded list") {
    let state = TorrentListReducer.State.previewLoaded()
    #if os(macOS)
        return NavigationStack {
            ScrollView {
                TorrentListView(store: .preview(state: state))
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #else
        return NavigationStack {
            List {
                TorrentListView(store: .preview(state: state))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #endif
}

#Preview("Loading skeletons") {
    let state = TorrentListReducer.State.previewLoading()
    #if os(macOS)
        return NavigationStack {
            ScrollView {
                TorrentListView(store: .preview(state: state))
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #else
        return NavigationStack {
            List {
                TorrentListView(store: .preview(state: state))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #endif
}

#Preview("Empty state") {
    let state = TorrentListReducer.State.previewEmpty()
    #if os(macOS)
        return NavigationStack {
            ScrollView {
                TorrentListView(store: .preview(state: state))
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #else
        return NavigationStack {
            List {
                TorrentListView(store: .preview(state: state))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #endif
}

#Preview("Error state") {
    let state = TorrentListReducer.State.previewError()
    #if os(macOS)
        return NavigationStack {
            ScrollView {
                TorrentListView(store: .preview(state: state))
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #else
        return NavigationStack {
            List {
                TorrentListView(store: .preview(state: state))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    #endif
}

extension Store where State == TorrentListReducer.State, Action == TorrentListReducer.Action {
    fileprivate static func preview(state: State) -> Store {
        Store(initialState: state) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    }
}

extension TorrentListReducer.State {
    fileprivate static func previewBase() -> Self {
        var state = Self()
        state.connectionEnvironment = ServerConnectionEnvironment.preview(server: .previewLocalHTTP)
        state.phase = .loaded
        return state
    }

    fileprivate static func previewLoaded() -> Self {
        var state = previewBase()
        state.items = IdentifiedArray(
            uniqueElements: [
                TorrentListItem.State(torrent: .previewDownloading),
                {
                    var torrent = Torrent.previewDownloading
                    torrent.id = .init(rawValue: 2)
                    torrent.name = "Swift 6 GM Seed"
                    torrent.status = .seeding
                    torrent.summary = .init(
                        progress: .init(
                            percentDone: 1,
                            totalSize: 8_000_000_000,
                            downloadedEver: 8_000_000_000,
                            uploadedEver: 4_200_000_000,
                            uploadRatio: 2.0,
                            etaSeconds: -1
                        ),
                        transfer: torrent.summary.transfer,
                        peers: .init(connected: 3, sources: [])
                    )
                    return TorrentListItem.State(torrent: torrent)
                }()
            ]
        )
        state.storageSummary = StorageSummary(
            totalBytes: 12_000_000_000,
            freeBytes: 4_000_000_000
        )
        return state
    }

    fileprivate static func previewLoading() -> Self {
        var state = previewBase()
        state.phase = .loading
        return state
    }

    fileprivate static func previewEmpty() -> Self {
        var state = previewBase()
        state.phase = .loaded
        state.items = []
        return state
    }

    fileprivate static func previewError() -> Self {
        var state = previewBase()
        state.phase = .offline(
            .init(message: "Не удалось подключиться к Transmission", lastUpdatedAt: nil))
        state.errorPresenter.banner = .init(
            message: "Не удалось подключиться к Transmission",
            retry: .refresh
        )
        state.items = []
        return state
    }
}
