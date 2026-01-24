import ComposableArchitecture
import Foundation

// swiftlint:disable type_body_length
// swiftlint:disable file_length

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

        init(server: ServerConfig, startEditing: Bool = false) {
            self.server = server
            self.torrentList.serverID = server.id
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
            self.coreReducer(state: &state, action: action)
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

    private func coreReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .task:
            let serverID = state.server.id
            return .merge(
                startConnectionIfNeeded(state: &state),
                loadPreferences(serverID: serverID),
                observePreferences(serverID: serverID)
            )

        case .editButtonTapped:
            state.editor = ServerFormReducer.State(mode: .edit(state.server))
            return .none

        case .settingsButtonTapped:
            state.settings = SettingsReducer.State(
                serverID: state.server.id,
                serverName: state.server.name,
                connectionEnvironment: state.connectionEnvironment
            )
            return .none

        case .diagnosticsButtonTapped:
            state.diagnostics = DiagnosticsReducer.State()
            return .none

        case .deleteButtonTapped:
            state.alert = AlertFactory.deleteConfirmation(
                title: L10n.tr("serverDetail.alert.delete.title"),
                message: L10n.tr("serverDetail.alert.delete.message"),
                confirmAction: .confirmDeletion,
                cancelAction: .cancelDeletion
            )
            return .none

        case .deleteCompleted(.success):
            state.isDeleting = false
            return .merge(
                .cancel(id: ConnectionCancellationID.connection),
                .send(.delegate(.serverDeleted(state.server.id)))
            )

        case .deleteCompleted(.failure(let error)):
            state.isDeleting = false
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.delete.title"),
                message: error.message,
                action: .dismiss
            )
            return .none

        case .httpWarningResetButtonTapped:
            httpWarningPreferencesStore.reset(state.server.httpWarningFingerprint)
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.httpWarningsReset.title"),
                message: L10n.tr("serverDetail.alert.httpWarningsReset.message"),
                buttonText: L10n.tr("serverDetail.alert.httpWarningsReset.button"),
                action: .dismiss
            )
            return .none

        case .resetTrustButtonTapped:
            state.alert = AlertFactory.confirmation(
                title: L10n.tr("serverDetail.alert.trustReset.title"),
                message: L10n.tr("serverDetail.alert.trustReset.message"),
                confirmText: L10n.tr("serverDetail.alert.trustReset.confirm"),
                confirmAction: .confirmReset,
                cancelAction: .cancelReset
            )
            return .none

        case .resetTrustSucceeded:
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.trustResetDone.title"),
                message: L10n.tr("serverDetail.alert.trustResetDone.message"),
                buttonText: L10n.tr("serverDetail.alert.trustResetDone.button"),
                action: .dismiss
            )
            return .none

        case .resetTrustFailed(let message):
            state.alert = AlertFactory.simpleAlert(
                title: L10n.tr("serverDetail.alert.trustResetFailed.title"),
                message: message,
                action: .dismiss
            )
            return .none

        case .retryConnectionButtonTapped:
            state.errorPresenter.banner = nil
            return startConnection(state: &state, force: true)

        case .alert(.presented(.confirmDeletion)):
            state.alert = nil
            state.isDeleting = true
            return deleteServer(state.server)

        case .alert(.presented(.confirmReset)):
            state.alert = nil
            return performTrustReset(for: state.server)

        case .alert(.presented(.cancelReset)), .alert(.presented(.cancelDeletion)):
            state.alert = nil
            return .none

        case .alert(.presented(.dismiss)):
            state.alert = nil
            return .none

        case .alert(.dismiss):
            return .none

        case .userPreferencesResponse(.success(let preferences)):
            state.preferences = preferences
            return applyDefaultSpeedLimitsIfNeeded(state: &state)

        case .userPreferencesResponse(.failure):
            return .none
        case .cacheKeyPrepared(let key):
            let changed = state.torrentList.cacheKey != key
            state.torrentList.cacheKey = key
            return changed ? .send(.torrentList(.restoreCachedSnapshot)) : .none

        case .connectionResponse(.success(let response)):
            let environment = response.environment.updatingRPCVersion(
                response.handshake.rpcVersion
            )
            state.connectionEnvironment = environment
            state.torrentDetail?.applyConnectionEnvironment(environment)
            state.addTorrent?.connectionEnvironment = environment
            state.connectionRetryAttempts = 0
            state.connectionState.phase = .ready(
                .init(
                    fingerprint: environment.fingerprint,
                    handshake: response.handshake
                )
            )
            state.torrentList.connectionEnvironment = environment
            state.torrentList.cacheKey = environment.cacheKey
            state.torrentList.handshake = response.handshake
            let effects: Effect<Action> = .concatenate(
                .send(.torrentList(.task)),
                .send(.torrentList(.refreshRequested))
            )
            return .merge(
                .cancel(id: ConnectionCancellationID.connectionRetry),
                effects,
                applyDefaultSpeedLimitsIfNeeded(state: &state)
            )

        case .connectionResponse(.failure(let error)):
            state.connectionEnvironment = nil
            state.lastAppliedDefaultSpeedLimits = nil
            state.torrentDetail?.applyConnectionEnvironment(nil)
            state.addTorrent?.connectionEnvironment = nil
            state.torrentList.connectionEnvironment = nil
            state.torrentList.handshake = nil
            let message = error.userFacingMessage
            state.connectionRetryAttempts += 1
            state.connectionState.phase = .offline(
                .init(
                    message: message,
                    attempt: state.connectionRetryAttempts
                )
            )
            state.errorPresenter.banner = .init(
                message: message,
                retry: .reconnect
            )
            let teardown: Effect<Action> = .send(.torrentList(.teardown))
            let offlineEffect: Effect<Action> = .send(
                .torrentList(.goOffline(message: message))
            )
            let cacheClear: Effect<Action> =
                isIncompatibleVersion(error)
                ? clearOfflineCache(serverID: state.server.id)
                : .none
            return .merge(
                teardown,
                offlineEffect,
                cacheClear,
                scheduleConnectionRetry(state: &state)
            )

        case .editor(.presented(.delegate(.didUpdate(let server)))):
            let shouldReconnect =
                state.server.connectionFingerprint != server.connectionFingerprint
            state.server = server
            state.torrentList.serverID = server.id
            let teardownEffect: Effect<Action> =
                shouldReconnect ? .send(.torrentList(.teardown)) : .none
            if shouldReconnect {
                state.torrentList = .init()
                state.torrentList.serverID = server.id
                state.connectionEnvironment = nil
                state.lastAppliedDefaultSpeedLimits = nil
            }
            let connectionEffect =
                shouldReconnect
                ? startConnection(state: &state, force: true) : .none
            return .concatenate(
                teardownEffect,
                .send(.delegate(.serverUpdated(server))),
                connectionEffect,
                .send(.editor(.dismiss))
            )

        case .editor(.presented(.delegate(.cancelled))):
            return .send(.editor(.dismiss))

        case .editor:
            return .none

        case .settings(.presented(.delegate(.pollingIntervalChanged))):
            return .send(.torrentList(.refreshRequested))

        case .settings(.presented(.delegate(.closeRequested))):
            state.settings = nil
            return .none

        case .settings:
            return .none

        case .diagnostics(.presented(.delegate(.closeRequested))):
            state.diagnostics = nil
            return .none

        case .diagnostics:
            return .none

        case .torrentDetail(.presented(.delegate(.removeRequested(let id, _)))):
            return .send(.torrentList(.removeTapped(id)))  // TorrentList manages the confirmation dialog now

        case .torrentDetail(.presented(.delegate(.closeRequested))):
            state.torrentDetail = nil
            return .none

        case .torrentDetail:
            return .none

        case .addTorrent(.presented(.delegate(.closeRequested))):
            state.addTorrent = nil
            return .none

        case .addTorrent:
            return .none

        case .fileImportResult(.success(let url)):
            state.addTorrent = AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .torrentFile(data: Data(), fileName: url.lastPathComponent),
                    sourceDescription: url.lastPathComponent
                ),
                connectionEnvironment: state.connectionEnvironment,
                serverID: state.server.id
            )
            // Для загрузки данных файла передаем управление в AddTorrent
            return .send(.addTorrent(.presented(.fileImportResult(.success(url)))))

        case .fileImportResult(.failure):
            return .none

        case .fileImportLoaded:
            return .none

        case .torrentList(.rowTapped(let id)):
            if let item = state.torrentList.items[id: id] {
                state.torrentDetail = TorrentDetailReducer.State(
                    torrentID: id,
                    torrent: item.torrent,
                    connectionEnvironment: state.connectionEnvironment
                )
            }
            return .none

        case .torrentList(.addTorrentButtonTapped):
            state.addTorrent = AddTorrentReducer.State(
                connectionEnvironment: state.connectionEnvironment,
                serverID: state.server.id
            )
            return .none

        case .torrentList:
            return .none

        case .errorPresenter(.retryRequested(.reconnect)):
            return .send(.retryConnectionButtonTapped)
        case .errorPresenter:
            return .none
        case .delegate:
            return .none
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
