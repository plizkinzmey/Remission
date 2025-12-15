import ComposableArchitecture
// swiftlint:disable file_length
import SwiftUI

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        container
            #if os(macOS)
                .toolbar {
                    if store.connectionEnvironment != nil {
                        ToolbarItem(placement: .principal) {
                            macOSToolbarControls
                        }
                    }
                }
            #else
                .searchable(
                    text: searchBinding,
                    placement: .automatic,
                    prompt: Text(L10n.tr("torrentList.search.prompt"))
                ) {
                    ForEach(searchSuggestions, id: \.self) { suggestion in
                        Text(suggestion)
                        .searchCompletion(suggestion)
                    }
                }
            #endif
            #if os(iOS)
                .refreshable {
                    await store.send(.refreshRequested).finish()
                }
            #endif
            #if !os(macOS)
                .toolbar {
                    if store.connectionEnvironment != nil {
                        ToolbarItem(placement: .primaryAction) {
                            addButton
                        }
                        ToolbarItem(placement: .secondaryAction) {
                            refreshButton
                        }
                    }
                }
            #endif
            .alert(
                $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
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
                        .frame(width: 28, height: 22)
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
                        text: searchBinding
                    )
                    .textFieldStyle(.plain)
                    .font(.body)
                }
                .accessibilityIdentifier("torrentlist_search_field")
            }
            .padding(.horizontal, 12)
            .frame(minWidth: 300, idealWidth: 420, maxWidth: 520)
            .frame(height: macOSToolbarPillHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12))
            )
        }
    #endif

    #if os(macOS)
        private var macOSToolbarPillHeight: CGFloat { 34 }
    #endif

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

                content

                if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                    Text(L10n.tr("torrentList.autorefresh.disabled"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                }
            }
        #else
            Section {
                content
                if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                    Text(L10n.tr("torrentList.autorefresh.disabled"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                }
            } header: {
                Text(L10n.tr("torrentList.section.title"))
                    .accessibilityIdentifier("torrent_list_header")
                    .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .top) {
                if store.isRefreshing {
                    refreshIndicator
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                }
            }
        #endif
    }

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
            controls
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

    private var searchBinding: Binding<String> {
        Binding(
            get: { store.searchQuery },
            set: { store.send(.searchQueryChanged($0)) }
        )
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
            .containerRelativeFrame([.horizontal, .vertical], alignment: .center)
            .accessibilityIdentifier("torrent_list_empty_state")
        #else
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("torrentList.empty.title"))
                    .font(.subheadline)
                    .bold()
                Text(L10n.tr("torrentList.empty.message"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button(L10n.tr("torrentList.action.refresh")) {
                        store.send(.refreshRequested)
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.tr("torrentList.action.add")) {
                        store.send(.addTorrentButtonTapped)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("torrent_list_empty_add_button")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
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
            Button {
                store.send(.rowTapped(item.id))
            } label: {
                TorrentRowView(item: item)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("torrent_list_item_\(item.id.rawValue)")
            .listRowInsets(.init(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(rowBackground(for: item))
        }
    }

    #if os(macOS)
        private var torrentRowsMacOS: some View {
            LazyVStack(spacing: 10) {
                ForEach(store.visibleItems) { item in
                    TorrentRowView(
                        item: item,
                        openRequested: { store.send(.rowTapped(item.id)) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12))
                    )
                }
            }
        }
    #endif

    private func rowBackground(for item: TorrentListItem.State) -> some View {
        let color: Color =
            item.torrent.status == .isolated
            ? Color.red.opacity(0.08)
            : Color.clear

        return RoundedRectangle(cornerRadius: 8)
            .fill(color)
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
                HStack {
                    sortPicker
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 4)
        #endif
    }

    #if os(macOS)
        private var filterAndSortRowMacOS: some View {
            ZStack(alignment: .trailing) {
                filterSegmentedControl
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)

                sortPicker
                    .labelsHidden()
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
    }

    private var sortPicker: some View {
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
    }

    private var refreshButton: some View {
        Button {
            store.send(.refreshRequested)
        } label: {
            Label(L10n.tr("torrentList.refresh.label"), systemImage: "arrow.clockwise")
        }
        .accessibilityIdentifier("torrentlist_refresh_button")
    }

    private var addButton: some View {
        Button {
            store.send(.addTorrentButtonTapped)
        } label: {
            Label(L10n.tr("torrentList.action.add"), systemImage: "plus")
        }
        .accessibilityIdentifier("torrentlist_add_button")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                #if os(macOS)
                    Text(item.torrent.name)
                        .font(.headline)
                        .lineLimit(2)
                        .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
                        .onTapGesture {
                            openRequested?()
                        }
                #else
                    Text(item.torrent.name)
                        .font(.headline)
                        .lineLimit(2)
                        .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
                #endif
                Spacer(minLength: 8)
                statusBadge
                #if os(macOS)
                    if let openRequested {
                        Button(action: openRequested) {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "torrent_row_open_button_\(item.torrent.id.rawValue)"
                        )
                        .accessibilityLabel(L10n.tr("Open torrent details"))
                    }
                #endif
            }

            ProgressView(value: item.metrics.progressFraction)
                .tint(progressColor)
                .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")
                .accessibilityValue(item.metrics.progressText)

            HStack(spacing: 12) {
                Label(item.metrics.progressText, systemImage: "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("torrent_row_progress_\(item.torrent.id.rawValue)")

                if let etaText = item.metrics.etaText {
                    Label(etaText, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Label(item.metrics.speedSummary, systemImage: "speedometer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
            }

            HStack(spacing: 12) {
                Label(
                    peersText,
                    systemImage: "person.2"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                Spacer()

                Text("ID \(item.id.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 6)
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

    private var peersText: String {
        "\(item.torrent.summary.peers.connected) peers"
    }

    private var statusBadge: some View {
        Text(statusTitle)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
            )
            .foregroundStyle(statusColor)
            .accessibilityIdentifier("torrent_list_item_status_\(item.id.rawValue)")
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
        case .stopped: return .gray
        case .checking, .checkWaiting: return .orange
        case .downloadWaiting, .seedWaiting: return .purple
        case .isolated: return .red
        }
    }

    private var progressColor: Color {
        statusColor
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
