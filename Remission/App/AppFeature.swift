import ComposableArchitecture
import Foundation

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var version: AppStateVersion
        var serverList: ServerListReducer.State
        var path: StackState<ServerDetailReducer.State>
        @Presents var settings: SettingsReducer.State?
        var pendingTorrentFileURL: URL?

        init(
            version: AppStateVersion = .latest,
            serverList: ServerListReducer.State = .init(),
            path: StackState<ServerDetailReducer.State> = .init()
        ) {
            self.version = version
            self.serverList = serverList
            self.path = path
        }
    }

    enum Action: Equatable {
        case serverList(ServerListReducer.Action)
        case path(StackAction<ServerDetailReducer.State, ServerDetailReducer.Action>)
        case openTorrentFile(URL)
        case settingsButtonTapped
        case settings(PresentationAction<SettingsReducer.Action>)
        case settingsDismissed
        case settingsLoaded(TaskResult<UserPreferences>)
    }

    @Dependency(\.userPreferencesRepository) var userPreferencesRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .openTorrentFile(let url):
                guard url.isFileURL else { return .none }
                guard url.pathExtension.lowercased() == "torrent" else { return .none }

                if let targetServer = preferredServer(in: state) {
                    return openTorrentFile(url, in: targetServer, state: &state)
                }

                state.pendingTorrentFileURL = url
                if state.serverList.isLoading == false {
                    return .merge(
                        .send(.serverList(.task)),
                        .send(.serverList(.addButtonTapped))
                    )
                }
                return .send(.serverList(.addButtonTapped))

            case .serverList(.delegate(.serverSelected(let server))):
                if let pendingURL = state.pendingTorrentFileURL {
                    state.pendingTorrentFileURL = nil
                    return openTorrentFile(pendingURL, in: server, state: &state)
                }
                state.path.append(ServerDetailReducer.State(server: server))
                return .none

            case .serverList(.delegate(.serverCreated(let server))):
                if let pendingURL = state.pendingTorrentFileURL {
                    state.pendingTorrentFileURL = nil
                    return openTorrentFile(pendingURL, in: server, state: &state)
                }
                state.path.append(ServerDetailReducer.State(server: server))
                return .none

            case .serverList(.serverRepositoryResponse(.success(let servers))):
                guard let pendingURL = state.pendingTorrentFileURL else { return .none }
                guard let targetServer = preferredServer(from: servers, in: state) else {
                    return .none
                }
                state.pendingTorrentFileURL = nil
                return openTorrentFile(pendingURL, in: targetServer, state: &state)

            case .serverList:
                return .none

            case .path(.element(id: _, action: .delegate(.serverUpdated(let server)))):
                if let index = state.serverList.servers.index(id: server.id) {
                    state.serverList.servers[index] = server
                }
                return .none

            case .path(.element(id: let id, action: .delegate(.serverDeleted(let serverID)))):
                state.path[id: id] = nil
                state.serverList.servers.remove(id: serverID)
                return .none

            case .path(.element(id: _, action: .delegate(.torrentSelected))):
                return .none

            case .path(.element(id: _, action: .delegate(.openSettingsRequested))):
                return .send(.settingsButtonTapped)

            case .path:
                return .none

            case .settingsButtonTapped:
                guard state.settings == nil, state.path.isEmpty else { return .none }
                return .run { send in
                    await send(
                        .settingsLoaded(
                            TaskResult {
                                try await userPreferencesRepository.load()
                            }
                        )
                    )
                }

            case .settings(.presented(.delegate(.closeRequested))):
                return .concatenate(
                    .send(.settings(.presented(.teardown))),
                    .send(.settingsDismissed)
                )

            case .settings(.dismiss):
                return .concatenate(
                    .send(.settings(.presented(.teardown))),
                    .send(.settingsDismissed)
                )

            case .settingsDismissed:
                state.settings = nil
                return .none

            case .settings(.presented) where state.settings == nil:
                // Игнорируем presented действия, если состояние настроек уже сброшено.
                // Это предотвращает предупреждения TCA когда UI отправляет события после dismiss.
                return .none

            case .settings:
                return .none

            case .settingsLoaded(.success(let preferences)):
                var settingsState = SettingsReducer.State(isLoading: false)
                settingsState.persistedPreferences = preferences
                settingsState.pollingIntervalSeconds = preferences.pollingInterval
                settingsState.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
                settingsState.isTelemetryEnabled = preferences.isTelemetryEnabled
                settingsState.defaultSpeedLimits = preferences.defaultSpeedLimits
                state.settings = settingsState
                return .none

            case .settingsLoaded(.failure(let error)):
                var settingsState = SettingsReducer.State(isLoading: false)
                settingsState.alert = AlertState {
                    TextState(L10n.tr("settings.alert.saveFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("settings.alert.close"))
                    }
                } message: {
                    TextState(error.localizedDescription)
                }
                state.settings = settingsState
                return .none
            }
        }
        .ifLet(\.$settings, action: \.settings) {
            SettingsReducer()
        }

        .forEach(\.path, action: \.path) {
            ServerDetailReducer()
        }

        Scope(state: \.serverList, action: \.serverList) {
            ServerListReducer()
        }
    }

    private func preferredServer(in state: State) -> ServerConfig? {
        if let lastID = state.path.ids.last,
            let server = state.path[id: lastID]?.server
        {
            return server
        }
        return preferredServer(from: Array(state.serverList.servers), in: state)
    }

    private func preferredServer(from servers: [ServerConfig], in state: State) -> ServerConfig? {
        if let lastID = state.path.ids.last,
            let server = state.path[id: lastID]?.server
        {
            return server
        }
        return servers.max { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
    }

    private func openTorrentFile(
        _ url: URL,
        in server: ServerConfig,
        state: inout State
    ) -> Effect<Action> {
        if let lastID = state.path.ids.last,
            let activeServer = state.path[id: lastID]?.server,
            activeServer.id == server.id
        {
            return .send(
                .path(.element(id: lastID, action: .fileImportResult(.success(url))))
            )
        }

        state.path.append(ServerDetailReducer.State(server: server))
        guard let targetID = state.path.ids.last else { return .none }
        return .send(
            .path(.element(id: targetID, action: .fileImportResult(.success(url))))
        )
    }
}
