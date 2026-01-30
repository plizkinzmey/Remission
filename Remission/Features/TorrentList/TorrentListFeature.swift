import ComposableArchitecture
import Dependencies
import Foundation
import UserNotifications

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
        var isSearchFieldVisible: Bool = false
        var isAwaitingConnection: Bool = false
    }

    enum Action: Equatable {
        case task
        case teardown
        case resetForReconnect
        case refreshRequested
        case commandRefreshRequested
        case searchQueryChanged(String)
        case toggleSearchField
        case hideSearchField
        case filterChanged(Filter)
        case categoryChanged(CategoryFilter)
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

    @Dependency(\.appClock) var appClock
    @Dependency(\.userPreferencesRepository) var userPreferencesRepository
    @Dependency(\.offlineCacheRepository) var offlineCacheRepository
    @Dependency(\.notificationClient) var notificationClient

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
                if let environment = state.connectionEnvironment {
                    state.cacheKey = environment.cacheKey
                }
                if state.items.isEmpty {
                    state.phase = .loading
                } else {
                    state.isAwaitingConnection = false
                }
                guard let serverID = state.serverID else {
                    return .none
                }
                return .merge(
                    loadPreferences(serverID: serverID),
                    observePreferences(serverID: serverID),
                    .run { _ in
                        _ = try await notificationClient.requestAuthorization([
                            .alert, .sound, .badge
                        ])
                    }
                )

            case .teardown:
                state.isRefreshing = false
                state.hasLoadedPreferences = false
                state.offlineState = nil
                state.errorPresenter.banner = nil
                state.pendingRemoveTorrentID = nil
                state.removingTorrentIDs.removeAll()
                state.inFlightCommands.removeAll()
                state.isAwaitingConnection = false
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .cancel(id: CancelID.polling),
                    .cancel(id: CancelID.preferences),
                    .cancel(id: CancelID.preferencesUpdates),
                    .cancel(id: CancelID.cache)
                )

            case .resetForReconnect:
                state.isRefreshing = false
                state.phase = .loading
                state.items.removeAll()
                state.storageSummary = nil
                state.offlineState = nil
                state.errorPresenter.banner = nil
                state.pendingRemoveTorrentID = nil
                state.removingTorrentIDs.removeAll()
                state.inFlightCommands.removeAll()
                state.lastSnapshotAt = nil
                state.isAwaitingConnection = true
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .cancel(id: CancelID.polling)
                )

            case .refreshRequested:
                state.failedAttempts = 0
                state.offlineState = nil
                state.isRefreshing = true
                return fetchTorrents(state: &state, trigger: .manualRefresh)

            case .commandRefreshRequested:
                return fetchTorrents(state: &state, trigger: .command)

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .none

            case .toggleSearchField:
                state.isSearchFieldVisible.toggle()
                if state.isSearchFieldVisible == false {
                    state.searchQuery = ""
                }
                return .none

            case .hideSearchField:
                state.isSearchFieldVisible = false
                state.searchQuery = ""
                return .none

            case .filterChanged(let filter):
                state.selectedFilter = filter
                return .none

            case .categoryChanged(let category):
                state.selectedCategory = category
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

            case .goOffline(let message):
                let offline = State.OfflineState(
                    message: message,
                    lastUpdatedAt: state.lastSnapshotAt
                )
                state.offlineState = offline
                state.phase = .offline(offline)
                state.isRefreshing = false
                state.isAwaitingConnection = false
                state.items.removeAll()
                state.storageSummary = nil
                let banner = Effect<Action>.send(
                    .errorPresenter(
                        .showBanner(
                            message: message,
                            retry: .refresh
                        )
                    )
                )
                return banner

            case .torrentsResponse(.success(let payload)):

                let previousItems = state.items

                // Проверяем, был ли список загружен ранее. Если phase == .loaded, значит это обновление (polling/refresh),

                // и мы должны уведомлять о новых торрентах (добавленных на другом устройстве).

                // Если нет (первая загрузка), уведомления для "новых" (всех) торрентов подавляем.

                let wasLoaded = state.phase == .loaded

                state.isRefreshing = false

                state.isAwaitingConnection = false

                state.errorPresenter.banner = nil

                state.lastSnapshotAt = payload.snapshotDate ?? state.lastSnapshotAt

                state.items = merge(

                    items: state.items,

                    with: payload.torrents,

                    removingIDs: state.removingTorrentIDs

                )

                let notificationsEffect: Effect<Action> = .run { [items = state.items] _ in

                    for newItem in items {

                        if let oldItem = previousItems[id: newItem.id] {

                            // 1. Логика для уже существовавших торрентов (изменение состояния)

                            // Check for completion

                            let wasNotFinished = oldItem.torrent.summary.progress.percentDone < 1.0

                            let isFinished = newItem.torrent.summary.progress.percentDone >= 1.0

                            if wasNotFinished && isFinished {

                                try? await notificationClient.sendNotification(

                                    L10n.tr("torrentList.notification.completed.title"),

                                    L10n.tr(
                                        "torrentList.notification.completed.body",
                                        newItem.torrent.name),

                                    "completed-\(newItem.id.rawValue)"

                                )

                            }

                            // Check for error

                            let hadNoError = oldItem.torrent.error == 0

                            let hasError = newItem.torrent.error != 0

                            if hadNoError && hasError {

                                try? await notificationClient.sendNotification(

                                    L10n.tr("torrentList.notification.error.title"),

                                    newItem.torrent.errorString.isEmpty

                                        ? L10n.tr(
                                            "torrentList.notification.error.body",
                                            newItem.torrent.name)

                                        : newItem.torrent.errorString,

                                    "error-\(newItem.id.rawValue)"

                                )

                            }

                        } else if wasLoaded {

                            // 2. Логика для НОВЫХ торрентов (добавленных удаленно),

                            // но только если это не первый запуск приложения.

                            // Если новый торрент появился сразу готовым (или почти готовым)

                            if newItem.torrent.summary.progress.percentDone >= 1.0 {

                                try? await notificationClient.sendNotification(

                                    L10n.tr("torrentList.notification.completed.title"),

                                    L10n.tr(
                                        "torrentList.notification.completed.body",
                                        newItem.torrent.name),

                                    "completed-\(newItem.id.rawValue)"

                                )

                            }

                            // Если новый торрент появился сразу с ошибкой

                            if newItem.torrent.error != 0 {

                                try? await notificationClient.sendNotification(

                                    L10n.tr("torrentList.notification.error.title"),

                                    newItem.torrent.errorString.isEmpty

                                        ? L10n.tr(
                                            "torrentList.notification.error.body",
                                            newItem.torrent.name)

                                        : newItem.torrent.errorString,

                                    "error-\(newItem.id.rawValue)"

                                )

                            }

                        }

                    }

                }

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
                    state.isAwaitingConnection = false
                } else if let offline = state.offlineState {
                    state.phase = .offline(offline)
                } else {
                    state.phase = .loaded
                    state.isAwaitingConnection = false
                }
                guard payload.isFromCache == false,
                    state.isPollingEnabled,
                    state.connectionEnvironment != nil
                else {
                    let finalEffect =
                        payload.isFromCache ? .none : Effect<Action>.cancel(id: CancelID.polling)
                    return .merge(notificationsEffect, finalEffect)
                }
                return .merge(notificationsEffect, schedulePolling(after: state.pollingInterval))

            case .storageUpdated(let summary):
                state.storageSummary = summary
                return .none

            case .torrentsResponse(.failure(let error)):
                if error is CancellationError {
                    return .none
                }
                let message = describe(error)
                state.isRefreshing = false
                state.isAwaitingConnection = false
                state.phase = .error(message)
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

extension TorrentListReducer.State {
    var visibleItems: IdentifiedArrayOf<TorrentListItem.State> {
        filteredVisibleItems()
    }
}

extension TorrentListReducer.State {
    var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matchesSearch(
        _ item: TorrentListItem.State,
        query: String
    ) -> Bool {
        guard query.isEmpty == false else { return true }
        return item.torrent.name.localizedCaseInsensitiveContains(query)
    }
}

// swiftlint:enable nesting type_body_length
