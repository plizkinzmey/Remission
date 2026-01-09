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
        @Presents var editor: ServerEditorReducer.State?
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
                self.editor = ServerEditorReducer.State(server: server)
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
        case editor(PresentationAction<ServerEditorReducer.Action>)
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

    var body: some Reducer<State, Action> {
        core
            .ifLet(\.$alert, action: \.alert) {
                EmptyReducer()
            }
            .ifLet(\.$editor, action: \.editor) {
                ServerEditorReducer()
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
        Scope(state: \.torrentList, action: \.torrentList) {
            TorrentListReducer()
        }
        Scope(state: \.errorPresenter, action: \.errorPresenter) {
            ErrorPresenter<ErrorRetry>()
        }
    }

    private var core: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                let hasReadyConnection: Bool = {
                    guard state.connectionEnvironment != nil else { return false }
                    if case .ready = state.connectionState.phase {
                        return true
                    }
                    return false
                }()
                var effects: [Effect<Action>] = [
                    loadPreferences(serverID: state.server.id),
                    observePreferences(serverID: state.server.id),
                    startConnectionIfNeeded(state: &state),
                    .send(.torrentList(.restoreCachedSnapshot))
                ]
                if hasReadyConnection {
                    effects.append(.send(.torrentList(.task)))
                    effects.append(.send(.torrentList(.refreshRequested)))
                }
                return .merge(effects)

            case .retryConnectionButtonTapped:
                state.connectionRetryAttempts = 0
                state.errorPresenter.banner = nil
                return .merge(
                    .cancel(id: ConnectionCancellationID.connectionRetry),
                    startConnection(state: &state, force: true)
                )

            case .editButtonTapped:
                state.editor = ServerEditorReducer.State(server: state.server)
                return .none

            case .settingsButtonTapped:
                state.settings = SettingsReducer.State(
                    serverID: state.server.id,
                    serverName: state.server.name
                )
                return .none

            case .diagnosticsButtonTapped:
                state.diagnostics = DiagnosticsReducer.State()
                return .none

            case .deleteButtonTapped:
                state.alert = makeDeleteAlert()
                return .none

            case .deleteCompleted(.success):
                state.isDeleting = false
                return .merge(
                    .cancel(id: ConnectionCancellationID.connection),
                    .send(.delegate(.serverDeleted(state.server.id)))
                )

            case .deleteCompleted(.failure(let error)):
                state.isDeleting = false
                state.alert = AlertState {
                    TextState(L10n.tr("serverDetail.alert.delete.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .httpWarningResetButtonTapped:
                httpWarningPreferencesStore.reset(state.server.httpWarningFingerprint)
                state.alert = AlertState {
                    TextState(L10n.tr("serverDetail.alert.httpWarningsReset.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("serverDetail.alert.httpWarningsReset.button"))
                    }
                } message: {
                    TextState(L10n.tr("serverDetail.alert.httpWarningsReset.message"))
                }
                return .none

            case .resetTrustButtonTapped:
                state.alert = AlertState {
                    TextState(L10n.tr("serverDetail.alert.trustReset.title"))
                } actions: {
                    ButtonState(role: .destructive, action: .confirmReset) {
                        TextState(L10n.tr("serverDetail.alert.trustReset.confirm"))
                    }
                    ButtonState(role: .cancel, action: .cancelReset) {
                        TextState(L10n.tr("serverDetail.alert.trustReset.cancel"))
                    }
                } message: {
                    TextState(L10n.tr("serverDetail.alert.trustReset.message"))
                }
                return .none

            case .resetTrustSucceeded:
                state.alert = AlertState {
                    TextState(L10n.tr("serverDetail.alert.trustResetDone.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("serverDetail.alert.trustResetDone.button"))
                    }
                } message: {
                    TextState(L10n.tr("serverDetail.alert.trustResetDone.message"))
                }
                return .none

            case .resetTrustFailed(let message):
                state.alert = AlertState {
                    TextState(L10n.tr("serverDetail.alert.trustResetFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(message)
                }
                return .none

            case .alert(.presented(.confirmReset)):
                state.alert = nil
                return performTrustReset(for: state.server)

            case .alert(.presented(.confirmDeletion)):
                state.alert = nil
                guard state.isDeleting == false else { return .none }
                state.isDeleting = true
                return deleteServer(state.server)

            case .alert(.presented(.cancelReset)):
                state.alert = nil
                return .none

            case .alert(.presented(.cancelDeletion)):
                state.alert = nil
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
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
                let message = describe(error)
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

            case .torrentList(.delegate(.openTorrent(let id))):
                guard let selectedItem = state.torrentList.items[id: id] else {
                    return .none
                }
                var detailState = TorrentDetailReducer.State(
                    torrent: selectedItem.torrent
                )
                detailState.applyConnectionEnvironment(state.torrentList.connectionEnvironment)
                state.torrentDetail = detailState
                return .none

            case .torrentList(.delegate(.addTorrentRequested)):
                state.addTorrent = AddTorrentReducer.State(
                    connectionEnvironment: state.connectionEnvironment
                )
                return .none

            case .torrentList:
                return .none

            case .torrentDetail(.presented(.delegate(.torrentUpdated(let torrent)))):
                return .send(.torrentList(.delegate(.detailUpdated(torrent))))

            case .torrentDetail(.presented(.delegate(.torrentRemoved(let identifier)))):
                return .concatenate(
                    .send(.torrentList(.delegate(.detailRemoved(identifier)))),
                    .send(.torrentDetail(.dismiss))
                )

            case .torrentDetail(.presented(.delegate(.closeRequested))):
                return .send(.torrentDetail(.dismiss))

            case .torrentDetail:
                return .none

            case .fileImportResult(.success(let url)):
                return handleFileImport(url: url, state: &state)

            case .fileImportResult(.failure(let message)):
                return handleFileImportFailure(message: message, state: &state)

            case .fileImportLoaded(.success(let input)):
                return handleFileImportLoaded(
                    result: .success(input),
                    state: &state
                )

            case .fileImportLoaded(.failure(let error)):
                return handleFileImportLoaded(
                    result: .failure(error),
                    state: &state
                )

            case .addTorrent(.presented(.delegate(.closeRequested))):
                return .send(.addTorrent(.dismiss))

            case .addTorrent(.presented(.delegate(.addCompleted(let result)))):
                return .send(.torrentList(.delegate(.added(result))))

            case .addTorrent:
                return .none

            case .settings(.presented(.delegate(.closeRequested))):
                return .concatenate(
                    .send(.settings(.presented(.teardown))),
                    .send(.settings(.dismiss))
                )

            case .settings(.dismiss):
                state.settings = nil
                return .none

            case .settings(.presented):
                return .none

            case .diagnostics(.presented(.delegate(.closeRequested))):
                return .concatenate(
                    .send(.diagnostics(.presented(.teardown))),
                    .send(.diagnostics(.dismiss))
                )

            case .diagnostics(.dismiss):
                state.diagnostics = nil
                return .none

            case .diagnostics(.presented):
                return .none

            case .userPreferencesResponse(.success(let preferences)):
                state.preferences = preferences
                return .merge(
                    applyDefaultSpeedLimitsIfNeeded(state: &state),
                    .send(.torrentList(.userPreferencesResponse(.success(preferences))))
                )

            case .userPreferencesResponse(.failure):
                return .none

            case .errorPresenter(.retryRequested(.reconnect)):
                return .send(.retryConnectionButtonTapped)

            case .errorPresenter:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private enum ConnectionCancellationID {
        case connection
        case preferences
        case preferencesUpdates
        case defaultSpeedLimits
        case connectionRetry
    }

    /// Проверяет, нужно ли переустанавливать подключение (изменился ли fingerprint
    /// или окружение невалидно) и инициирует коннект при необходимости.
    private func startConnectionIfNeeded(
        state: inout State
    ) -> Effect<Action> {
        let fingerprint = state.server.connectionFingerprint
        guard case .ready(let ready) = state.connectionState.phase,
            ready.fingerprint == fingerprint,
            state.connectionEnvironment?.isValid(for: state.server) == true
        else {
            return startConnection(state: &state, force: false)
        }
        return .none
    }

    /// Запускает процесс подключения к серверу, учитывая флаг принудительного запуска.
    private func startConnection(
        state: inout State,
        force: Bool
    ) -> Effect<Action> {
        guard case .connecting = state.connectionState.phase,
            force == false
        else {
            state.connectionEnvironment = nil
            state.lastAppliedDefaultSpeedLimits = nil
            state.connectionState.phase = .connecting
            state.connectionRetryAttempts = 0
            return .merge(
                .cancel(id: ConnectionCancellationID.connectionRetry),
                connect(server: state.server)
            )
        }

        return .none
    }

    /// Создаёт `ServerConnectionEnvironment` и выполняет handshake Transmission.
    private func connect(server: ServerConfig) -> Effect<Action> {
        .run { send in
            await send(
                .connectionResponse(
                    TaskResult {
                        let environment = try await serverConnectionEnvironmentFactory.make(server)
                        await send(.cacheKeyPrepared(environment.cacheKey))
                        let handshake = try await environment.dependencies.transmissionClient
                            .performHandshake()
                        return ConnectionResponse(environment: environment, handshake: handshake)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true)
    }

    private func performTrustReset(for server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                await send(.resetTrustSucceeded)
            } catch {
                let message = (error as NSError).localizedDescription
                await send(.resetTrustFailed(message))
            }
        }
    }

    private func deleteServer(_ server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                if let key = server.credentialsKey {
                    try await credentialsRepository.delete(key: key)
                }
                try await offlineCacheRepository.clear(server.id)
                httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                _ = try await serverConfigRepository.delete([server.id])
                await send(.deleteCompleted(.success))
            } catch {
                let message = (error as NSError).localizedDescription
                await send(.deleteCompleted(.failure(DeletionError(message: message))))
            }
        }
    }

    private func clearOfflineCache(serverID: UUID) -> Effect<Action> {
        .run { _ in
            do {
                try await offlineCacheRepository.clear(serverID)
            } catch {
                // Кеш опционален: игнорируем ошибки очистки, чтобы не блокировать UX.
            }
        }
    }

    private func isIncompatibleVersion(_ error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        if case .versionUnsupported = apiError {
            return true
        }
        return false
    }

    private func loadPreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            await send(
                .userPreferencesResponse(
                    TaskResult {
                        try await userPreferencesRepository.load(serverID: serverID)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.preferences, cancelInFlight: true)
    }

    private func observePreferences(serverID: UUID) -> Effect<Action> {
        .run { send in
            let stream = userPreferencesRepository.observe(serverID: serverID)
            for await preferences in stream {
                await send(.userPreferencesResponse(.success(preferences)))
            }
        }
        .cancellable(id: ConnectionCancellationID.preferencesUpdates, cancelInFlight: true)
    }

    private func applyDefaultSpeedLimitsIfNeeded(
        state: inout State
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment,
            let preferences = state.preferences
        else {
            return .none
        }
        let limits = preferences.defaultSpeedLimits
        guard state.lastAppliedDefaultSpeedLimits != limits else {
            return .none
        }
        state.lastAppliedDefaultSpeedLimits = limits
        return applyDefaultSpeedLimits(
            limits: limits,
            environment: environment
        )
    }

    private func applyDefaultSpeedLimits(
        limits: UserPreferences.DefaultSpeedLimits,
        environment: ServerConnectionEnvironment
    ) -> Effect<Action> {
        .run { _ in
            try await withDependencies {
                environment.apply(to: &$0)
            } operation: {
                @Dependency(\.sessionRepository) var sessionRepository
                let download = SessionState.SpeedLimits.Limit(
                    isEnabled: limits.downloadKilobytesPerSecond != nil,
                    kilobytesPerSecond: limits.downloadKilobytesPerSecond ?? 0
                )
                let upload = SessionState.SpeedLimits.Limit(
                    isEnabled: limits.uploadKilobytesPerSecond != nil,
                    kilobytesPerSecond: limits.uploadKilobytesPerSecond ?? 0
                )
                let update = SessionRepository.SessionUpdate(
                    speedLimits: .init(
                        download: download,
                        upload: upload,
                        alternative: nil
                    )
                )
                _ = try await sessionRepository.updateState(update)
            }
        }
        .cancellable(
            id: ConnectionCancellationID.defaultSpeedLimits,
            cancelInFlight: true
        )
    }

    private func scheduleConnectionRetry(
        state: inout State
    ) -> Effect<Action> {
        guard state.connectionRetryAttempts < maxConnectionRetryAttempts else {
            return .none
        }
        let delay = backoffDelay(for: state.connectionRetryAttempts)
        return .run { send in
            let clock = appClock.clock()
            do {
                try await clock.sleep(for: delay)
                await send(.retryConnectionButtonTapped)
            } catch is CancellationError {
                return
            }
        }
        .cancellable(id: ConnectionCancellationID.connectionRetry, cancelInFlight: true)
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

    private var maxConnectionRetryAttempts: Int { 5 }

    private func makeDeleteAlert() -> AlertState<AlertAction> {
        AlertState {
            TextState(L10n.tr("serverDetail.alert.delete.title"))
        } actions: {
            ButtonState(role: .destructive, action: .confirmDeletion) {
                TextState(L10n.tr("serverDetail.alert.delete.confirm"))
            }
            ButtonState(role: .cancel, action: .cancelDeletion) {
                TextState(L10n.tr("serverDetail.alert.delete.cancel"))
            }
        } message: {
            TextState(L10n.tr("serverDetail.alert.delete.message"))
        }
    }

}

private func describe(_ error: Error) -> String {
    if let localized = error as? LocalizedError {
        if let description = localized.errorDescription {
            if description.isEmpty == false {
                return description
            }
        }
    }

    let nsError = error as NSError
    let description = nsError.localizedDescription
    return description.isEmpty ? String(describing: error) : description
}

extension AlertState where Action == ServerDetailReducer.AlertAction {
    static func connectionFailure(message: String) -> Self {
        AlertState {
            TextState(L10n.tr("serverDetail.alert.connectionFailed.title"))
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
    }
}

// swiftlint:enable type_body_length
