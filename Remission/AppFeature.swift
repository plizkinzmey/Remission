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
        case settingsButtonTapped
        case settings(PresentationAction<SettingsReducer.Action>)
        case settingsDismissed
        case settingsLoaded(TaskResult<UserPreferences>)
    }

    @Dependency(\.userPreferencesRepository) var userPreferencesRepository

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .serverList(.delegate(.serverSelected(let server))):
                state.path.append(ServerDetailReducer.State(server: server))
                return .none

            case .serverList(.delegate(.serverCreated(let server))):
                state.path.append(ServerDetailReducer.State(server: server))
                return .none

            case .serverList(.delegate(.serverEditRequested(let server))):
                state.path.append(ServerDetailReducer.State(server: server, startEditing: true))
                return .none

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

            case .path:
                return .none

            case .settingsButtonTapped:
                guard state.settings == nil else { return .none }
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
}
