import ComposableArchitecture
import SwiftUI

struct TorrentListView: View {
    @Bindable var store: StoreOf<TorrentListReducer>

    var body: some View {
        Section("Торренты") {
            if store.connectionEnvironment == nil {
                disconnectedView
            } else {
                controls
                content
                if store.isPollingEnabled == false {
                    Text("Автообновление отключено в настройках.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("torrentlist_autorefresh_disabled")
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var content: some View {
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

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Загружаем торренты…")
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Торренты отсутствуют")
                .font(.subheadline)
                .bold()
            Text("Добавьте .torrent или magnet, либо измените фильтры выше.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Обновить") {
                store.send(.refreshRequested)
            }
            .buttonStyle(.bordered)
        }
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
        }
    }

    private var controls: some View {
        Group {
            #if os(macOS)
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    searchField
                        .frame(maxWidth: 260)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Фильтр")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        filterPicker
                            .frame(maxWidth: 240)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сортировка")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        sortPicker
                            .frame(maxWidth: 180)
                    }
                }
            #else
                VStack(spacing: 12) {
                    searchField
                    filterPicker
                    sortPicker
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            #endif
        }
        .padding(.vertical, 6)
    }

    private var searchField: some View {
        TextField(
            "Поиск по названию или ETA",
            text: Binding(
                get: { store.searchQuery },
                set: { store.send(.searchQueryChanged($0)) }
            )
        )
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("torrentlist_search_field")
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
        .pickerStyle(.segmented)
        .accessibilityIdentifier("torrentlist_filter_picker")
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
        .pickerStyle(.menu)
        .accessibilityIdentifier("torrentlist_sort_picker")
    }

    private var torrentRows: some View {
        ForEach(store.visibleItems) { item in
            Button {
                store.send(.rowTapped(item.id))
            } label: {
                TorrentRowView(item: item)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TorrentRowView: View {
    var item: TorrentListItem.State

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.torrent.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                statusBadge
            }

            ProgressView(value: item.metrics.progressFraction)
                .tint(progressColor)

            HStack {
                Text(item.metrics.progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let etaText = item.metrics.etaText {
                    Text(etaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.metrics.speedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(statusTitle)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
            )
            .foregroundStyle(statusColor)
    }

    private var statusTitle: String {
        switch item.torrent.status {
        case .stopped: return "Остановлен"
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
