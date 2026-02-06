import ComposableArchitecture
import Dependencies
import Foundation

/// Управляет списком торрентов на экране деталей сервера:
/// держит состояние фильтров, поиск, polling и взаимодействие с `TorrentRepository`.
struct TorrentListReducer: Reducer {
    struct VisibleItemsSignature: Equatable {
        var query: String
        var filter: Filter
        var category: CategoryFilter
        var itemsRevision: Int
        var metricsRevision: Int
    }
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

    @ObservableState
    struct State: Equatable {
        var serverID: UUID?
        var cacheKey: OfflineCacheKey?
        var connectionEnvironment: ServerConnectionEnvironment?
        var phase: Phase = .idle
        var items: IdentifiedArrayOf<TorrentListItem.State> = []
        var itemsRevision: Int = 0
        var metricsRevision: Int = 0
        var visibleItemsCache: IdentifiedArrayOf<TorrentListItem.State> = []
        var visibleItemsSignature: VisibleItemsSignature?
        var searchSuggestions: [String] = []
        var searchQuery: String = ""
        var selectedFilter: Filter = .all
        var selectedCategory: CategoryFilter = .all
        var isRefreshing: Bool = false
        var isPollingEnabled: Bool = true
        var failedAttempts: Int = 0
        var pollingInterval: Duration = .seconds(5)
        var adaptivePollingInterval: Duration?
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
        var lastMetricsUpdateAt: Date?
    }

    @CasePathable
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
        case errorPresenter(ErrorPresenter<Retry>.Action)
        case pollingTick
        case userPreferencesResponse(TaskResult<UserPreferences>)
        case torrentsResponse(TaskResult<FetchSuccess>)
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

    enum CancelID: Hashable {
        case fetch
        case polling
        case preferences
        case preferencesUpdates
        case cache
        case command(Torrent.Identifier)
    }

    @Dependency(\.appClock) var appClock
    @Dependency(\.dateProvider) var dateProvider
    @Dependency(\.userPreferencesRepository) var userPreferencesRepository
    @Dependency(\.offlineCacheRepository) var offlineCacheRepository
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.appLogger) var appLogger
}
