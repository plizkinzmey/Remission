import ComposableArchitecture
import Dependencies
import Foundation

// swiftlint:disable nesting type_body_length

/// Управляет списком торрентов на экране деталей сервера:
/// держит состояние фильтров, поиск, polling и взаимодействие с `TorrentRepository`.
@Reducer
struct TorrentListReducer {
    @ObservableState
    struct State: Equatable {
        enum Phase: Equatable {
            case idle
            case loading
            case loaded
            case error(String)
        }

        var connectionEnvironment: ServerConnectionEnvironment?
        var phase: Phase = .idle
        var items: IdentifiedArrayOf<TorrentListItem.State> = []
        var searchQuery: String = ""
        var selectedFilter: Filter = .all
        var sortOrder: SortOrder = .name
        var isRefreshing: Bool = false
        var isPollingEnabled: Bool = true
        var failedAttempts: Int = 0
        var pollingInterval: Duration = .seconds(5)
        var hasLoadedPreferences: Bool = false
        @Presents var alert: AlertState<AlertAction>?

        var visibleItems: IdentifiedArrayOf<TorrentListItem.State> {
            let query = normalizedSearchQuery
            let filtered = items.filter {
                selectedFilter.matches($0) && matchesSearch($0, query: query)
            }
            let sorted = filtered.sorted {
                sortOrder.areInIncreasingOrder(lhs: $0, rhs: $1)
            }
            return IdentifiedArray(uniqueElements: sorted)
        }

        private var normalizedSearchQuery: String {
            searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        fileprivate func matchesSearch(
            _ item: TorrentListItem.State,
            query: String
        ) -> Bool {
            guard query.isEmpty == false else { return true }
            return item.torrent.name.localizedCaseInsensitiveContains(query)
        }
    }

    enum Action: Equatable {
        case task
        case teardown
        case refreshRequested
        case searchQueryChanged(String)
        case filterChanged(Filter)
        case sortChanged(SortOrder)
        case rowTapped(Torrent.Identifier)
        case addTorrentButtonTapped
        case pollingTick
        case userPreferencesResponse(TaskResult<UserPreferences>)
        case torrentsResponse(TaskResult<[Torrent]>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum Delegate: Equatable {
        case openTorrent(Torrent.Identifier)
        case addTorrentRequested
    }

    enum Filter: String, Equatable, CaseIterable, Hashable, Sendable {
        case all
        case downloading
        case seeding
        case errors

        var title: String {
            switch self {
            case .all: return "Все"
            case .downloading: return "Загрузки"
            case .seeding: return "Раздачи"
            case .errors: return "Ошибки"
            }
        }

        fileprivate func matches(_ item: TorrentListItem.State) -> Bool {
            switch self {
            case .all:
                return true
            case .downloading:
                return [.downloading, .downloadWaiting, .checkWaiting, .checking]
                    .contains(item.torrent.status)
            case .seeding:
                return [.seeding, .seedWaiting].contains(item.torrent.status)
            case .errors:
                // Transmission помечает проблемные торренты статусом isolated.
                return item.torrent.status == .isolated
            }
        }
    }

    enum SortOrder: String, Equatable, CaseIterable, Hashable, Sendable {
        case name
        case progress
        case downloadSpeed
        case eta

        var title: String {
            switch self {
            case .name: return "Имя"
            case .progress: return "Прогресс"
            case .downloadSpeed: return "Скорость"
            case .eta: return "ETA"
            }
        }

        fileprivate func areInIncreasingOrder(
            lhs: TorrentListItem.State,
            rhs: TorrentListItem.State
        ) -> Bool {
            switch self {
            case .name:
                return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                    != .orderedDescending

            case .progress:
                if lhs.metrics.progressFraction == rhs.metrics.progressFraction {
                    return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                        != .orderedDescending
                }
                return lhs.metrics.progressFraction > rhs.metrics.progressFraction

            case .downloadSpeed:
                let lhsSpeed = lhs.torrent.summary.transfer.downloadRate
                let rhsSpeed = rhs.torrent.summary.transfer.downloadRate
                if lhsSpeed == rhsSpeed {
                    return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                        != .orderedDescending
                }
                return lhsSpeed > rhsSpeed

            case .eta:
                let lhsEta = lhs.metrics.etaSeconds > 0 ? lhs.metrics.etaSeconds : .max
                let rhsEta = rhs.metrics.etaSeconds > 0 ? rhs.metrics.etaSeconds : .max
                if lhsEta == rhsEta {
                    return lhs.torrent.name.localizedCaseInsensitiveCompare(rhs.torrent.name)
                        != .orderedDescending
                }
                return lhsEta < rhsEta
            }
        }
    }

    @Dependency(\.appClock) var appClock
    @Dependency(\.userPreferencesRepository) var userPreferencesRepository

    private enum CancelID: Hashable {
        case fetch
        case polling
        case preferences
        case preferencesUpdates
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                if state.items.isEmpty {
                    state.phase = .loading
                }
                state.alert = nil
                return .merge(
                    loadPreferences(),
                    observePreferences()
                )

            case .teardown:
                state.isRefreshing = false
                state.hasLoadedPreferences = false
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .cancel(id: CancelID.polling),
                    .cancel(id: CancelID.preferences),
                    .cancel(id: CancelID.preferencesUpdates)
                )

            case .refreshRequested:
                state.alert = nil
                state.failedAttempts = 0
                return fetchTorrents(state: &state, trigger: .manualRefresh)

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .none

            case .filterChanged(let filter):
                state.selectedFilter = filter
                return .none

            case .sortChanged(let sort):
                state.sortOrder = sort
                return .none

            case .rowTapped(let id):
                return .send(.delegate(.openTorrent(id)))

            case .addTorrentButtonTapped:
                return .send(.delegate(.addTorrentRequested))

            case .pollingTick:
                return fetchTorrents(state: &state, trigger: .polling)

            case .userPreferencesResponse(.success(let preferences)):
                let newInterval = duration(from: preferences.pollingInterval)
                let newAutoRefresh = preferences.isAutoRefreshEnabled
                let intervalChanged = state.pollingInterval != newInterval
                let autoRefreshChanged = state.isPollingEnabled != newAutoRefresh
                state.pollingInterval = newInterval
                state.isPollingEnabled = newAutoRefresh

                if state.hasLoadedPreferences == false {
                    state.hasLoadedPreferences = true
                    return fetchTorrents(state: &state, trigger: .initial)
                }

                guard intervalChanged || autoRefreshChanged else {
                    return .none
                }
                return .merge(
                    .cancel(id: CancelID.polling),
                    fetchTorrents(state: &state, trigger: .preferencesChanged)
                )

            case .userPreferencesResponse(.failure(let error)):
                let effect = fetchTorrents(state: &state, trigger: .initial)
                state.alert = .preferencesError(message: describe(error))
                return effect

            case .torrentsResponse(.success(let torrents)):
                state.phase = .loaded
                state.isRefreshing = false
                state.failedAttempts = 0
                state.alert = nil
                state.items = merge(items: state.items, with: torrents)
                guard state.isPollingEnabled, state.connectionEnvironment != nil else {
                    return .cancel(id: CancelID.polling)
                }
                return schedulePolling(after: state.pollingInterval)

            case .torrentsResponse(.failure(let error)):
                if error is CancellationError {
                    return .none
                }
                let message = describe(error)
                state.isRefreshing = false
                state.failedAttempts += 1
                if state.items.isEmpty {
                    state.phase = .error(message)
                }
                state.alert = .networkError(message: message)
                guard state.isPollingEnabled, state.connectionEnvironment != nil else {
                    return .cancel(id: CancelID.polling)
                }
                return schedulePolling(after: backoffDelay(for: state.failedAttempts))

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private enum FetchTrigger {
        case initial
        case manualRefresh
        case polling
        case preferencesChanged
    }

    /// Загружает пользовательские настройки, чтобы инициализировать polling interval
    /// и другие параметры обновления списка.
    private func loadPreferences() -> Effect<Action> {
        .run { send in
            await send(
                .userPreferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load()
                    }
                )
            )
        }
        .cancellable(id: CancelID.preferences, cancelInFlight: true)
    }

    /// Наблюдает за изменениями настроек и пробрасывает их в reducer.
    private func observePreferences() -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe()
            for await preferences in stream {
                await send(.userPreferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: CancelID.preferencesUpdates, cancelInFlight: true)
    }

    /// Выполняет запрос списка торрентов с учётом выбранного триггера (initial/manual/polling).
    private func fetchTorrents(
        state: inout State,
        trigger: FetchTrigger
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.isRefreshing = false
            return .none
        }

        switch trigger {
        case .initial:
            if state.items.isEmpty {
                state.phase = .loading
            }
        case .manualRefresh:
            state.isRefreshing = true
        case .polling:
            break
        case .preferencesChanged:
            break
        }

        state.alert = nil

        return .run { send in
            await send(
                .torrentsResponse(
                    TaskResult {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.torrentRepository) var repository: TorrentRepository
                            return try await repository.fetchList()
                        }
                    }
                )
            )
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }

    /// Планирует следующий polling tick через указанный интервал.
    private func schedulePolling(after delay: Duration) -> Effect<Action> {
        .run { send in
            let clock = appClock.clock()
            do {
                try await clock.sleep(for: delay)
                await send(.pollingTick)
            } catch is CancellationError {
                return
            }
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }

    private func merge(
        items: IdentifiedArrayOf<TorrentListItem.State>,
        with torrents: [Torrent]
    ) -> IdentifiedArrayOf<TorrentListItem.State> {
        var updated: IdentifiedArrayOf<TorrentListItem.State> = []
        updated.reserveCapacity(torrents.count)

        for torrent in torrents {
            if var existing = items[id: torrent.id] {
                existing.update(with: torrent)
                updated.append(existing)
            } else {
                updated.append(TorrentListItem.State(torrent: torrent))
            }
        }

        return updated
    }

    private func backoffDelay(for failures: Int) -> Duration {
        guard failures > 0 else { return .seconds(1) }
        let values: [Duration] = [
            .seconds(1),
            .seconds(2),
            .seconds(4),
            .seconds(8),
            .seconds(16),
            .seconds(30)
        ]
        let index = min(failures - 1, values.count - 1)
        return values[index]
    }

    private func duration(from interval: TimeInterval) -> Duration {
        .milliseconds(Int(interval * 1_000))
    }

    private func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError {
            if let description = localized.errorDescription {
                if description.isEmpty == false {
                    return description
                }
            }
        }
        return String(describing: error)
    }
}

extension AlertState where Action == TorrentListReducer.AlertAction {
    static func networkError(message: String) -> AlertState {
        AlertState {
            TextState("Не удалось обновить список торрентов")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Понятно")
            }
        } message: {
            TextState(message)
        }
    }

    static func preferencesError(message: String) -> AlertState {
        AlertState {
            TextState("Не удалось загрузить настройки")
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Закрыть")
            }
        } message: {
            TextState(message)
        }
    }
}

// swiftlint:enable nesting type_body_length

enum TorrentListItem {}

extension TorrentListItem {
    @ObservableState
    struct State: Equatable, Identifiable, Sendable {
        var torrent: Torrent
        var metrics: Metrics

        var id: Torrent.Identifier { torrent.id }

        init(torrent: Torrent) {
            self.torrent = torrent
            self.metrics = Metrics(torrent: torrent)
        }

        mutating func update(with torrent: Torrent) {
            self.torrent = torrent
            self.metrics = Metrics(torrent: torrent)
        }
    }

    struct Metrics: Equatable, Sendable {
        var progressFraction: Double
        var progressText: String
        var downloadRateText: String
        var uploadRateText: String
        var speedSummary: String
        var etaSeconds: Int
        var etaText: String?

        init(torrent: Torrent) {
            let clampedProgress = min(max(torrent.summary.progress.percentDone, 0), 1)
            self.progressFraction = clampedProgress
            self.progressText = String(format: "%.1f%%", clampedProgress * 100)
            self.downloadRateText = Metrics.format(
                bytesPerSecond: torrent.summary.transfer.downloadRate)
            self.uploadRateText = Metrics.format(
                bytesPerSecond: torrent.summary.transfer.uploadRate)
            self.speedSummary = "↓ \(downloadRateText)/с · ↑ \(uploadRateText)/с"
            self.etaSeconds = torrent.summary.progress.etaSeconds
            self.etaText = Metrics.formatETA(seconds: torrent.summary.progress.etaSeconds)
        }

        private static func format(bytesPerSecond: Int) -> String {
            guard bytesPerSecond > 0 else {
                return "0 Б"
            }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            formatter.allowedUnits = .useAll
            formatter.includesUnit = true
            return formatter.string(fromByteCount: Int64(bytesPerSecond))
        }

        private static func formatETA(seconds: Int) -> String? {
            guard seconds > 0 else { return nil }
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
            formatter.unitsStyle = .abbreviated
            formatter.maximumUnitCount = 2
            if let formatted = formatter.string(from: TimeInterval(seconds)) {
                return "ETA \(formatted)"
            }
            return nil
        }
    }
}
