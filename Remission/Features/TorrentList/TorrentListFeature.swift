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
        struct InFlightCommand: Equatable {
            var command: TorrentCommand
            var initialStatus: Torrent.Status
        }
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
        var selectedCategory: CategoryFilter = .all
        var sortOrder: SortOrder = .name
        var isRefreshing: Bool = false
        var isPollingEnabled: Bool = true
        var failedAttempts: Int = 0
        var pollingInterval: Duration = .seconds(5)
        var hasLoadedPreferences: Bool = false
        var offlineState: OfflineState?
        var lastSnapshotAt: Date?
        var errorPresenter: ErrorPresenter<Retry>.State = .init()
        var pendingRemoveTorrentID: Torrent.Identifier?
        var removingTorrentIDs: Set<Torrent.Identifier> = []
        var inFlightCommands: [Torrent.Identifier: InFlightCommand] = [:]
        @Presents var removeConfirmation: ConfirmationDialogState<RemoveConfirmationAction>?
        var storageSummary: StorageSummary?
        var handshake: TransmissionHandshakeResult?

        var visibleItems: IdentifiedArrayOf<TorrentListItem.State> {
            let query = normalizedSearchQuery
            // NOTE: при списках 1000+ элементов стоит кешировать результаты фильтра/сортировки,
            // сохраняя их в State и инвалидации через DiffID. Это избавит от лишних O(n log n)
            // пересчётов при каждом `body` и заметно разгрузит UI при больших библиотеках.
            let filtered = items.filter {
                selectedFilter.matches($0)
                    && selectedCategory.matches($0)
                    && matchesSearch($0, query: query)
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
        case commandRefreshRequested
        case searchQueryChanged(String)
        case filterChanged(Filter)
        case categoryChanged(CategoryFilter)
        case sortChanged(SortOrder)
        case rowTapped(Torrent.Identifier)
        case startTapped(Torrent.Identifier)
        case pauseTapped(Torrent.Identifier)
        case verifyTapped(Torrent.Identifier)
        case removeTapped(Torrent.Identifier)
        case removeConfirmation(PresentationAction<RemoveConfirmationAction>)
        case commandResponse(Torrent.Identifier, Result<Bool, CommandError>)
        case addTorrentButtonTapped
        case errorPresenter(ErrorPresenter<State.Retry>.Action)
        case pollingTick
        case userPreferencesResponse(TaskResult<UserPreferences>)
        case restoreCachedSnapshot
        case torrentsResponse(TaskResult<State.FetchSuccess>)
        case storageUpdated(StorageSummary?)
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

    enum RemoveConfirmationAction: Equatable {
        case deleteTorrentOnly
        case deleteWithData
        case cancel
    }

    struct CommandError: Error, Equatable {
        var message: String
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

    enum CategoryFilter: String, Equatable, CaseIterable, Hashable, Sendable {
        case all
        case programs
        case movies
        case series
        case books
        case other

        var title: String {
            switch self {
            case .all:
                return L10n.tr("torrentList.category.all")
            case .programs:
                return TorrentCategory.programs.title
            case .movies:
                return TorrentCategory.movies.title
            case .series:
                return TorrentCategory.series.title
            case .books:
                return TorrentCategory.books.title
            case .other:
                return TorrentCategory.other.title
            }
        }

        fileprivate func matches(_ item: TorrentListItem.State) -> Bool {
            guard let category = mappedCategory else { return true }
            return TorrentCategory.category(from: item.torrent.tags) == category
        }

        private var mappedCategory: TorrentCategory? {
            switch self {
            case .all:
                return nil
            case .programs:
                return .programs
            case .movies:
                return .movies
            case .series:
                return .series
            case .books:
                return .books
            case .other:
                return .other
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

    enum CancelID: Hashable {
        case fetch
        case polling
        case preferences
        case preferencesUpdates
        case cache
        case command(Torrent.Identifier)
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
                guard let serverID = state.serverID else {
                    return .send(.restoreCachedSnapshot)
                }
                return .merge(
                    loadPreferences(serverID: serverID),
                    observePreferences(serverID: serverID),
                    .send(.restoreCachedSnapshot)
                )

            case .teardown:
                state.isRefreshing = false
                state.hasLoadedPreferences = false
                state.offlineState = nil
                state.errorPresenter.banner = nil
                state.pendingRemoveTorrentID = nil
                state.removingTorrentIDs.removeAll()
                state.inFlightCommands.removeAll()
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

            case .commandRefreshRequested:
                return fetchTorrents(state: &state, trigger: .command)

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .none

            case .filterChanged(let filter):
                state.selectedFilter = filter
                return .none

            case .categoryChanged(let category):
                state.selectedCategory = category
                return .none

            case .sortChanged(let sort):
                state.sortOrder = sort
                return .none

            case .rowTapped(let id):
                return .send(.delegate(.openTorrent(id)))

            case .startTapped(let id):
                return performCommand(.start, torrentID: id, state: &state)

            case .pauseTapped(let id):
                return performCommand(.pause, torrentID: id, state: &state)

            case .verifyTapped(let id):
                return performCommand(.verify, torrentID: id, state: &state)

            case .removeTapped(let id):
                let name = state.items[id: id]?.torrent.name ?? ""
                state.pendingRemoveTorrentID = id
                state.removeConfirmation = .removeTorrent(name: name)
                return .none

            case .removeConfirmation(.presented(.deleteTorrentOnly)):
                state.removeConfirmation = nil
                guard let id = state.pendingRemoveTorrentID else { return .none }
                state.pendingRemoveTorrentID = nil
                state.removingTorrentIDs.insert(id)
                if var item = state.items[id: id] {
                    item.isRemoving = true
                    state.items[id: id] = item
                }
                return performCommand(.remove(deleteData: false), torrentID: id, state: &state)

            case .removeConfirmation(.presented(.deleteWithData)):
                state.removeConfirmation = nil
                guard let id = state.pendingRemoveTorrentID else { return .none }
                state.pendingRemoveTorrentID = nil
                state.removingTorrentIDs.insert(id)
                if var item = state.items[id: id] {
                    item.isRemoving = true
                    state.items[id: id] = item
                }
                return performCommand(.remove(deleteData: true), torrentID: id, state: &state)

            case .removeConfirmation(.presented(.cancel)):
                state.pendingRemoveTorrentID = nil
                state.removeConfirmation = nil
                return .none

            case .removeConfirmation:
                return .none

            case .commandResponse(_, .success):
                return .send(.commandRefreshRequested)

            case .commandResponse(let id, .failure(let error)):
                state.inFlightCommands.removeValue(forKey: id)
                state.removingTorrentIDs.remove(id)
                if var item = state.items[id: id] {
                    item.isRemoving = false
                    state.items[id: id] = item
                }
                let message = error.message
                return .send(
                    .errorPresenter(
                        .showAlert(
                            title: L10n.tr("torrentDetail.error.title"),
                            message: message,
                            retry: nil
                        )
                    )
                )

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
                state.items = merge(
                    items: state.items,
                    with: payload.torrents,
                    removingIDs: state.removingTorrentIDs
                )
                let currentIDs = Set(state.items.map(\.id))
                state.removingTorrentIDs.formIntersection(currentIDs)
                state.inFlightCommands = state.inFlightCommands.filter { id, inFlight in
                    guard let item = state.items[id: id] else { return false }
                    if case .remove = inFlight.command { return true }
                    return item.torrent.status == inFlight.initialStatus
                }
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

            case .storageUpdated(let summary):
                state.storageSummary = summary
                return .none

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
        .ifLet(\.$removeConfirmation, action: \.removeConfirmation)
        Scope(state: \.errorPresenter, action: \.errorPresenter) {
            ErrorPresenter<TorrentListReducer.State.Retry>()
        }
    }
}

// swiftlint:enable nesting type_body_length
