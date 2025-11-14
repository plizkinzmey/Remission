import ComposableArchitecture
import SwiftUI

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        Section("Торренты") {
            content
            if store.connectionEnvironment != nil && store.isPollingEnabled == false {
                Text("Автообновление отключено в настройках.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("torrentlist_autorefresh_disabled")
            }
        }
        .safeAreaInset(edge: .top) {
            if store.isRefreshing {
                refreshIndicator
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
            }
        }
        .searchable(
            text: searchBinding,
            placement: .automatic,
            prompt: Text("Поиск по названию или ETA")
        ) {
            ForEach(searchSuggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .searchCompletion(suggestion)
            }
        }
        #if os(iOS)
            .refreshable {
                await store.send(.refreshRequested).finish()
            }
        #endif
        .toolbar {
            if store.connectionEnvironment != nil {
                #if os(macOS)
                    ToolbarItemGroup {
                        filterPicker
                        sortPicker
                    }
                    ToolbarItem {
                        refreshButton
                    }
                #else
                    ToolbarItemGroup(placement: .secondaryAction) {
                        filterMenu
                        sortMenu
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        refreshButton
                    }
                #endif
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var content: some View {
        if store.connectionEnvironment == nil {
            disconnectedView
        } else {
            switch store.phase {
            case .idle:
                EmptyView()

            case .loading:
                if store.isRefreshing == false {
                    loadingView
                }

            case .loaded:
                if store.visibleItems.isEmpty {
                    emptyStateView
                } else {
                    torrentRows
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
            store.items
                .map(\.torrent.name)
                .filter { name in
                    guard query.isEmpty == false else { return true }
                    return name.localizedCaseInsensitiveContains(query) == false
                }
                .prefix(5)
        )
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Загружаем торренты…")
                .font(.callout)
        }
        .accessibilityIdentifier("torrent_list_loading")
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Нет подключения")
                .font(.subheadline)
                .bold()
            Text("Дождитесь установления соединения с сервером, чтобы увидеть список торрентов.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Нет активных торрентов")
                .font(.subheadline)
                .bold()
            Text("Импортируйте .torrent/magnet или измените фильтры выше.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Обновить") {
                    store.send(.refreshRequested)
                }
                .buttonStyle(.bordered)

                Button("Добавить торрент") {
                    store.send(.addTorrentButtonTapped)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("torrent_list_empty_add_button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .accessibilityIdentifier("torrent_list_empty_state")
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Не удалось обновить список", systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
            Text(message.isEmpty ? "Попробуйте повторить попытку позже." : message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Повторить") {
                store.send(.refreshRequested)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("torrent_list_error_retry")
        }
        .padding(.vertical, 8)
    }

    private var torrentRows: some View {
        LazyVStack(spacing: 12) {
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
        .padding(.vertical, 4)
    }

    private func rowBackground(for item: TorrentListItem.State) -> some View {
        let color: Color =
            item.torrent.status == .isolated
            ? Color.red.opacity(0.08)
            : Color.clear

        return RoundedRectangle(cornerRadius: 8)
            .fill(color)
    }

    private var filterPicker: some View {
        Picker(
            "Фильтр",
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
        .frame(maxWidth: 240)
    }

    private var sortPicker: some View {
        Picker(
            "Сортировка",
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
        .frame(maxWidth: 180)
    }

    private var filterMenu: some View {
        Menu {
            Picker(
                "Фильтр",
                selection: Binding(
                    get: { store.selectedFilter },
                    set: { store.send(.filterChanged($0)) }
                )
            ) {
                ForEach(TorrentListReducer.Filter.allCases, id: \.self) { filter in
                    Text(filter.title).tag(filter)
                }
            }
        } label: {
            Label(
                "Фильтр: \(store.selectedFilter.title)",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityIdentifier("torrentlist_filter_menu")
    }

    private var sortMenu: some View {
        Menu {
            Picker(
                "Сортировка",
                selection: Binding(
                    get: { store.sortOrder },
                    set: { store.send(.sortChanged($0)) }
                )
            ) {
                ForEach(TorrentListReducer.SortOrder.allCases, id: \.self) { sort in
                    Text(sort.title).tag(sort)
                }
            }
        } label: {
            Label("Сортировка: \(store.sortOrder.title)", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityIdentifier("torrentlist_sort_menu")
    }

    private var refreshButton: some View {
        Button {
            store.send(.refreshRequested)
        } label: {
            Label("Обновить список", systemImage: "arrow.clockwise")
        }
        .accessibilityIdentifier("torrentlist_refresh_button")
    }
}

extension TorrentListView {
    private var refreshIndicator: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Обновляем список…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("torrent_list_refresh_indicator")
    }

}

private struct TorrentRowView: View {
    var item: TorrentListItem.State

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.torrent.name)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
                Spacer(minLength: 8)
                statusBadge
            }

            ProgressView(value: item.metrics.progressFraction)
                .tint(progressColor)
                .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")

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
        case .stopped: return "Пауза"
        case .checkWaiting: return "Ожидает проверку"
        case .checking: return "Проверка"
        case .downloadWaiting: return "В очереди"
        case .downloading: return "Скачивание"
        case .seedWaiting: return "Ожидает раздачу"
        case .seeding: return "Раздача"
        case .isolated: return "Ошибка"
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

#Preview("Torrent list") {
    NavigationStack {
        List {
            TorrentListView(
                store: Store(
                    initialState: {
                        var state = TorrentListReducer.State()
                        state.connectionEnvironment = ServerConnectionEnvironment.preview(
                            server: .previewLocalHTTP
                        )
                        state.phase = .loaded
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
                    }()
                ) {
                    TorrentListReducer()
                }
            )
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
