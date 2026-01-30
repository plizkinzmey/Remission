import ComposableArchitecture
import Foundation

/// Главный reducer экрана деталей сервера: отвечает за подключение, управление
/// сервером и встраивает `TorrentListReducer` для отображения торрентов.
@Reducer
struct ServerDetailReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        @Presents var alert: AlertState<AlertAction>?
        var errorPresenter: ErrorPresenter<ErrorRetry>.State = .init()
        @Presents var editor: ServerFormReducer.State?
        @Presents var settings: SettingsReducer.State?
        @Presents var diagnostics: DiagnosticsReducer.State?
        @Presents var torrentDetail: TorrentDetailReducer.State?
        @Presents var addTorrent: AddTorrentReducer.State?
        var isDeleting: Bool = false
        var connectionState: ConnectionState = .init()
        var connectionEnvironment: ServerConnectionEnvironment?
        var torrentList: TorrentListReducer.State = .init()
        var connectionRetryAttempts: Int = 0
        var preferences: UserPreferences?
        var lastAppliedDefaultSpeedLimits: UserPreferences.DefaultSpeedLimits?
        var pendingAddTorrentInput: PendingTorrentInput?

        init(server: ServerConfig, startEditing: Bool = false) {
            self.server = server
            var torrentListState = TorrentListReducer.State()
            torrentListState.serverID = server.id
            torrentListState.isAwaitingConnection = true
            self.torrentList = torrentListState
            if startEditing {
                self.editor = ServerFormReducer.State(mode: .edit(server))
            }
        }
    }

    enum Action: Equatable {
        case task
        case editButtonTapped
        case settingsButtonTapped
        case diagnosticsButtonTapped
        case deleteButtonTapped
        case deleteCompleted(DeletionResult)
        case httpWarningResetButtonTapped
        case resetTrustButtonTapped
        case resetTrustSucceeded
        case resetTrustFailed(String)
        case retryConnectionButtonTapped
        case connectionRetryTick
        case errorPresenter(ErrorPresenter<ErrorRetry>.Action)
        case cacheKeyPrepared(OfflineCacheKey)
        case connectionResponse(TaskResult<ConnectionResponse>)
        case userPreferencesResponse(TaskResult<UserPreferences>)
        case torrentList(TorrentListReducer.Action)
        case editor(PresentationAction<ServerFormReducer.Action>)
        case settings(PresentationAction<SettingsReducer.Action>)
        case diagnostics(PresentationAction<DiagnosticsReducer.Action>)
        case torrentDetail(PresentationAction<TorrentDetailReducer.Action>)
        case addTorrent(PresentationAction<AddTorrentReducer.Action>)
        case fileImportResult(FileImportResult)
        case fileImportLoaded(Result<PendingTorrentInput, FileImportError>)
        case addTorrentDataLoaded(PendingTorrentInput, String?)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum ErrorRetry: Equatable {
        case reconnect
    }

    enum AlertAction: Equatable {
        case confirmReset
        case cancelReset
        case dismiss
        case confirmDeletion
        case cancelDeletion
    }

    enum Delegate: Equatable {
        case serverUpdated(ServerConfig)
        case serverDeleted(UUID)
        case torrentSelected(Torrent.Identifier)
    }

    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore
    @Dependency(\.transmissionTrustStoreClient) var transmissionTrustStoreClient
    @Dependency(\.serverConnectionEnvironmentFactory) var serverConnectionEnvironmentFactory
    @Dependency(\.torrentFileLoader) var torrentFileLoader
    @Dependency(\.userPreferencesRepository) var userPreferencesRepository
    @Dependency(\.appClock) var appClock
    @Dependency(\.offlineCacheRepository) var offlineCacheRepository

    var body: some ReducerOf<Self> {
        Scope(state: \.torrentList, action: \.torrentList) {
            TorrentListReducer()
        }

        Reduce { state, action in
            .merge(
                connectionReducer(state: &state, action: action),
                managementReducer(state: &state, action: action),
                navigationReducer(state: &state, action: action),
                importReducer(state: &state, action: action)
            )
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$editor, action: \.editor) {
            ServerFormReducer()
        }
        .ifLet(\.$settings, action: \.settings) {
            SettingsReducer()
        }
        .ifLet(\.$diagnostics, action: \.diagnostics) {
            DiagnosticsReducer()
        }
        .ifLet(\.$torrentDetail, action: \.torrentDetail) {
            TorrentDetailReducer()
        }
        .ifLet(\.$addTorrent, action: \.addTorrent) {
            AddTorrentReducer()
        }
    }

    enum ConnectionCancellationID: Hashable {
        case connection
        case preferences
        case preferencesUpdates
        case defaultSpeedLimits
        case connectionRetry
    }
}
