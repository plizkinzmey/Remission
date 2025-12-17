import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AppFeatureTests {
    @Test
    func selectingServerPushesDetail() async {
        var server = ServerConfig.previewLocalHTTP
        let identifier = UUID()
        server.id = identifier
        let store = TestStoreFactory.makeAppTestStore(
            initialState: {
                var state: AppReducer.State = .init()
                state.serverList.servers = [server]
                return state
            }(),
            configure: { dependencies in
                dependencies.transmissionClient = .testValue
            }
        )

        await store.send(.serverList(.serverTapped(identifier)))
        await store.receive(.serverList(.delegate(.serverSelected(server))))

        #expect(store.state.path.last?.server == server)
        #expect(store.state.path.count == 1)
    }

    @Test
    func bootstrapStateResetsLegacyPathBeforeReducerStarts() {
        var serverList = ServerListReducer.State()
        serverList.servers = [ServerConfig.previewLocalHTTP]
        let detailState = ServerDetailReducer.State(server: .previewLocalHTTP)
        let legacyState = AppReducer.State(
            version: .legacy,
            serverList: serverList,
            path: StackState([detailState])
        )

        let initialState = AppBootstrap.makeInitialState(
            arguments: [],
            targetVersion: .latest,
            existingState: legacyState
        )

        let store = TestStoreFactory.makeAppTestStore(
            initialState: initialState
        )

        #expect(store.state.version == .latest)
        #expect(store.state.path.isEmpty)
        #expect(store.state.serverList.servers == serverList.servers)
    }

    @Test("settings открываются и закрываются через AppReducer")
    func settingsPresentation() async {
        let preferences = UserPreferences.default
        let store = TestStoreFactory.makeAppTestStore(configure: { dependencies in
            dependencies.userPreferencesRepository = .inMemory(
                store: InMemoryUserPreferencesRepositoryStore(
                    preferences: preferences
                )
            )
        })

        await store.send(.settingsButtonTapped)

        await store.receive(.settingsLoaded(.success(preferences))) {
            var settingsState = SettingsReducer.State(isLoading: false)
            settingsState.persistedPreferences = preferences
            settingsState.pollingIntervalSeconds = preferences.pollingInterval
            settingsState.isAutoRefreshEnabled = preferences.isAutoRefreshEnabled
            settingsState.isTelemetryEnabled = preferences.isTelemetryEnabled
            settingsState.defaultSpeedLimits = preferences.defaultSpeedLimits
            $0.settings = settingsState
        }

        await store.send(.settings(.presented(.delegate(.closeRequested))))

        await store.receive(.settingsDismissed) {
            $0.settings = nil
        }
    }
}
