// swiftlint:disable file_length
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
            case offline(OfflineState)
        }

        struct OfflineState: Equatable {
            var message: String
            var lastUpdatedAt: Date?
        }

        struct FetchSuccess: Equatable {
            var torrents: [Torrent]
            var isFromCache: Bool
            var snapshotDate: Date?
        }

        enum Retry: Equatable {
            case refresh
        }

        var serverID: UUID?
        var cacheKey: OfflineCacheKey?
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
        var offlineState: OfflineState?
        var lastSnapshotAt: Date?
        var errorPresenter: ErrorPresenter<Retry>.State = .init()

        var visibleItems: IdentifiedArrayOf<TorrentListItem.State> {
            let query = normalizedSearchQuery
            // NOTE: при списках 1000+ элементов стоит кешировать результаты фильтра/сортировки,
            // сохраняя их в State и инвалидации через DiffID. Это избавит от лишних O(n log n)
            // пересчётов при каждом `body` и заметно разгрузит UI при больших библиотеках.
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
        case errorPresenter(ErrorPresenter<State.Retry>.Action)
        case pollingTick
        case userPreferencesResponse(TaskResult<UserPreferences>)
        case restoreCachedSnapshot
        case torrentsResponse(TaskResult<State.FetchSuccess>)
        case goOffline(message: String)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case openTorrent(Torrent.Identifier)
        case addTorrentRequested
        case added(TorrentRepository.AddResult)
        case detailUpdated(Torrent)
        case detailRemoved(Torrent.Identifier)
    }

    enum Filter: String, Equatable, CaseIterable, Hashable, Sendable {
        case all
        case downloading
        case seeding
        case errors

        var title: String {
            switch self {
            case .all: return L10n.tr("torrentList.filter.all")
            case .downloading: return L10n.tr("torrentList.filter.downloading")
            case .seeding: return L10n.tr("torrentList.filter.seeding")
            case .errors: return L10n.tr("torrentList.filter.errors")
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
            case .name: return L10n.tr("torrentList.sort.name")
            case .progress: return L10n.tr("torrentList.sort.progress")
            case .downloadSpeed: return L10n.tr("torrentList.sort.speed")
            case .eta: return L10n.tr("torrentList.sort.eta")
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
    @Dependency(\.offlineCacheRepository) var offlineCacheRepository

    private enum CancelID: Hashable {
        case fetch
        case polling
        case preferences
        case preferencesUpdates
        case cache
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                if let environment = state.connectionEnvironment, state.cacheKey == nil {
                    state.cacheKey = environment.cacheKey
                }
                if state.items.isEmpty {
                    state.phase = .loading
                }
                return .send(.restoreCachedSnapshot)

            case .teardown:
                state.isRefreshing = false
                state.hasLoadedPreferences = false
                state.offlineState = nil
                state.errorPresenter.banner = nil
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .cancel(id: CancelID.polling),
                    .cancel(id: CancelID.preferences),
                    .cancel(id: CancelID.preferencesUpdates),
                    .cancel(id: CancelID.cache)
                )

            case .refreshRequested:
                state.failedAttempts = 0
                state.offlineState = nil
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
                return restartPolling(state: &state)

            case .userPreferencesResponse(.failure(let error)):
                let effect = fetchTorrents(state: &state, trigger: .initial)
                let message = describe(error)
                let alert = Effect<Action>.send(
                    .errorPresenter(
                        .showAlert(
                            title: L10n.tr("torrentList.alert.preferencesFailed.title"),
                            message: message,
                            retry: .refresh
                        )
                    )
                )
                return .merge(effect, alert)

            case .restoreCachedSnapshot:
                guard let cacheKey = state.cacheKey else {
                    return .none
                }
                return loadCachedSnapshot(cacheKey: cacheKey)

            case .goOffline(let message):
                let offline = State.OfflineState(
                    message: message,
                    lastUpdatedAt: state.lastSnapshotAt
                )
                state.offlineState = offline
                state.phase = .offline(offline)
                state.isRefreshing = false
                let banner = Effect<Action>.send(
                    .errorPresenter(
                        .showBanner(
                            message: message,
                            retry: .refresh
                        )
                    )
                )
                return .merge(.send(.restoreCachedSnapshot), banner)

            case .torrentsResponse(.success(let payload)):
                state.isRefreshing = false
                state.errorPresenter.banner = nil
                state.lastSnapshotAt = payload.snapshotDate ?? state.lastSnapshotAt
                state.items = merge(items: state.items, with: payload.torrents)
                if payload.isFromCache == false {
                    state.failedAttempts = 0
                    state.offlineState = nil
                    state.phase = .loaded
                } else if let offline = state.offlineState {
                    state.phase = .offline(offline)
                } else {
                    state.phase = .loaded
                }
                guard payload.isFromCache == false,
                    state.isPollingEnabled,
                    state.connectionEnvironment != nil
                else {
                    return payload.isFromCache ? .none : .cancel(id: CancelID.polling)
                }
                return schedulePolling(after: state.pollingInterval)

            case .torrentsResponse(.failure(let error)):
                if error is CancellationError {
                    return .none
                }
                let message = describe(error)
                state.isRefreshing = false
                state.failedAttempts += 1
                let offline = State.OfflineState(
                    message: message,
                    lastUpdatedAt: state.lastSnapshotAt
                )
                state.offlineState = offline
                state.phase = .offline(offline)
                state.errorPresenter.banner = .init(
                    message: message,
                    retry: .refresh
                )
                guard state.isPollingEnabled,
                    state.connectionEnvironment != nil,
                    state.failedAttempts < maxRetryAttempts
                else {
                    return .cancel(id: CancelID.polling)
                }
                let retryEffect = schedulePolling(after: backoffDelay(for: state.failedAttempts))
                return retryEffect

            case .errorPresenter(.retryRequested(.refresh)):
                return .send(.refreshRequested)

            case .errorPresenter:
                return .none

            case .delegate(.detailUpdated(let torrent)):
                return handleDetailUpdated(
                    state: &state,
                    torrent: torrent
                )

            case .delegate(.added(let result)):
                return handleTorrentAdded(
                    state: &state,
                    result: result
                )

            case .delegate(.detailRemoved(let identifier)):
                return handleDetailRemoved(
                    state: &state,
                    identifier: identifier
                )

            case .delegate:
                return .none
            }
        }
        Scope(state: \.errorPresenter, action: \.errorPresenter) {
            ErrorPresenter<TorrentListReducer.State.Retry>()
        }
    }

    private enum FetchTrigger {
        case initial
        case manualRefresh
        case polling
        case preferencesChanged
        case command
    }

    private enum TorrentListOfflineError: Error, LocalizedError {
        case connectionUnavailable

        var errorDescription: String? {
            L10n.tr("torrentList.state.noConnection.message")
        }
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
            // AsyncStream может завершиться (например, если storage выгружен). Тогда цикл завершится,
            // и редьюсер больше не увидит обновлений до повторного вызова .observePreferences().
            for await preferences in stream {
                await send(.userPreferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: CancelID.preferencesUpdates, cancelInFlight: true)
    }

    /// Загружает кешированный список торрентов, если он доступен, и пробрасывает его в reducer.
    private func loadCachedSnapshot(cacheKey: OfflineCacheKey) -> Effect<Action> {
        .run { send in
            let client = offlineCacheRepository.client(cacheKey)
            guard let snapshot = try await client.load(),
                let cached = snapshot.torrents
            else { return }
            await send(
                .torrentsResponse(
                    .success(
                        State.FetchSuccess(
                            torrents: cached.value,
                            isFromCache: true,
                            snapshotDate: cached.updatedAt
                        )
                    )
                )
            )
        }
        .cancellable(id: CancelID.cache, cancelInFlight: true)
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    /// Выполняет запрос списка торрентов с учётом выбранного триггера (initial/manual/polling).
    private func fetchTorrents(
        state: inout State,
        trigger: FetchTrigger
    ) -> Effect<Action> {
        if state.serverID == nil {
            state.serverID = state.connectionEnvironment?.serverID ?? state.cacheKey?.serverID
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
        case .command:
            state.isRefreshing = false
        }

        state.errorPresenter.banner = nil

        guard let environment = state.connectionEnvironment else {
            state.isRefreshing = false
            guard let cacheKey = state.cacheKey else { return .none }

            return .run { send in
                let client = offlineCacheRepository.client(cacheKey)
                guard let snapshot = try await client.load() else { return }
                guard let cached = snapshot.torrents else { return }

                await send(
                    .torrentsResponse(
                        .success(
                            State.FetchSuccess(
                                torrents: cached.value,
                                isFromCache: true,
                                snapshotDate: cached.updatedAt
                            )
                        )
                    )
                )
                await send(
                    .torrentsResponse(.failure(TorrentListOfflineError.connectionUnavailable)))
            }
            .cancellable(id: CancelID.fetch, cancelInFlight: true)
        }

        return .run { send in
            do {
                let torrents = try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    return try await repository.fetchList()
                }
                let snapshot = (try? await environment.snapshot.load()) ?? nil
                let updatedAt = snapshot?.torrents?.updatedAt
                await send(
                    .torrentsResponse(
                        .success(
                            State.FetchSuccess(
                                torrents: torrents,
                                isFromCache: false,
                                snapshotDate: updatedAt
                            )
                        )
                    )
                )
            } catch {
                if let snapshot = try? await environment.snapshot.load(),
                    let cached = snapshot.torrents
                {
                    await send(
                        .torrentsResponse(
                            .success(
                                State.FetchSuccess(
                                    torrents: cached.value,
                                    isFromCache: true,
                                    snapshotDate: cached.updatedAt
                                )
                            )
                        )
                    )
                }
                await send(.torrentsResponse(.failure(error)))
            }
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    private func restartPolling(state: inout State) -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.polling),
            fetchTorrents(state: &state, trigger: .preferencesChanged)
        )
    }

    private func handleDetailUpdated(
        state: inout State,
        torrent: Torrent
    ) -> Effect<Action> {
        if var existing = state.items[id: torrent.id] {
            existing.update(with: torrent)
            state.items[id: torrent.id] = existing
        } else {
            state.items.append(TorrentListItem.State(torrent: torrent))
        }
        state.phase = .loaded
        state.errorPresenter.banner = nil
        state.failedAttempts = 0
        state.isRefreshing = false
        return detailSyncEffect(state: &state)
    }

    private func handleTorrentAdded(
        state: inout State,
        result: TorrentRepository.AddResult
    ) -> Effect<Action> {
        guard state.connectionEnvironment != nil else {
            return .none
        }
        // Оптимистично добавляем placeholder сразу, а фактические данные приходят асинхронным fetch.
        // Первый poll/refresh перезапишет элемент через merge, поэтому видимое «мигание» допустимо.
        if state.items[id: result.id] == nil {
            let placeholder = makePlaceholderTorrent(addResult: result)
            state.items.append(TorrentListItem.State(torrent: placeholder))
        }
        state.phase = .loaded
        state.errorPresenter.banner = nil
        state.failedAttempts = 0
        state.isRefreshing = false

        let fetchEffect = fetchTorrents(state: &state, trigger: .command)
        return .merge(
            .cancel(id: CancelID.polling),
            fetchEffect
        )
    }

    private func handleDetailRemoved(
        state: inout State,
        identifier: Torrent.Identifier
    ) -> Effect<Action> {
        state.items.remove(id: identifier)
        state.phase = .loaded
        state.errorPresenter.banner = nil
        state.failedAttempts = 0
        state.isRefreshing = false
        return detailSyncEffect(state: &state)
    }

    private func detailSyncEffect(state: inout State) -> Effect<Action> {
        guard state.connectionEnvironment != nil else {
            return .none
        }
        let fetchEffect = fetchTorrents(state: &state, trigger: .command)
        return .merge(
            .cancel(id: CancelID.polling),
            fetchEffect
        )
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
        // Поддерживаем «живой» список: обновляем существующие элементы, чтобы сохранить
        // анимации/привязки SwiftUI, и добавляем новые торренты без полной пересборки.
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

    private func makePlaceholderTorrent(
        addResult: TorrentRepository.AddResult
    ) -> Torrent {
        let zeroLimits = Torrent.Transfer.SpeedLimit(isEnabled: false, kilobytesPerSecond: 0)
        let summary = Torrent.Summary(
            progress: .init(
                percentDone: 0,
                totalSize: 0,
                downloadedEver: 0,
                uploadedEver: 0,
                uploadRatio: 0,
                etaSeconds: -1
            ),
            transfer: .init(
                downloadRate: 0,
                uploadRate: 0,
                downloadLimit: zeroLimits,
                uploadLimit: zeroLimits
            ),
            peers: .init(connected: 0, sources: [])
        )
        return Torrent(
            id: addResult.id,
            name: addResult.name,
            status: .downloadWaiting,
            summary: summary
        )
    }

    private func backoffDelay(for failures: Int) -> Duration {
        // Экспоненциальный backoff, который снижает нагрузку на RPC при каскаде ошибок.
        // Задержка растёт до 30 c и не увеличивается далее, чтобы не блокировать UI.
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

    private var maxRetryAttempts: Int { 5 }

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

// swiftlint:enable nesting type_body_length

// swiftlint:enable file_length
