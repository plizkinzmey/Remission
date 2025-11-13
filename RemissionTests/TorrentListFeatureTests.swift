import Clocks
import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("TorrentListReducer")
struct TorrentListReducerTests {
    @MainActor
    @Test("Загрузка настроек и запуск polling по .task")
    func taskLoadsPreferencesAndStartsPolling() async {
        let clock = TestClock<Duration>()
        let torrents: [Torrent] = [.previewDownloading]
        let repository = TorrentRepository.test(
            fetchList: {
                torrents
            }
        )
        let preferences = UserPreferences(
            pollingInterval: 3,
            isAutoRefreshEnabled: true,
            defaultSpeedLimits: .init(
                downloadKilobytesPerSecond: nil,
                uploadKilobytesPerSecond: nil
            )
        )

        let store = makeStore(
            clock: clock,
            repository: repository,
            preferences: preferences
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.receive(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.isPollingEnabled = true
        }

        let expectedItems = IdentifiedArrayOf(
            uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
        )

        await store.receive(.torrentsResponse(.success(torrents))) {
            $0.phase = .loaded
            $0.items = expectedItems
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        await clock.advance(by: .milliseconds(Int(preferences.pollingInterval * 1_000)))

        await store.receive(.pollingTick)

        await store.receive(.torrentsResponse(.success(torrents))) {
            $0.items = expectedItems
            $0.failedAttempts = 0
        }
    }

    @MainActor
    @Test("Ошибки переводят редьюсер в error-phase и используют backoff")
    func errorPathTriggersBackoffAndAlert() async {
        enum DummyError: Error, LocalizedError {
            case failed

            var errorDescription: String? { "failed" }
        }

        let clock = TestClock<Duration>()
        let repository = TorrentRepository.test(
            fetchList: {
                throw DummyError.failed
            }
        )

        let preferences = UserPreferences.default

        let store = makeStore(
            clock: clock,
            repository: repository,
            preferences: preferences
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.receive(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.isPollingEnabled = preferences.isAutoRefreshEnabled
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            $0.phase = .error("failed")
            $0.alert = .networkError(message: "failed")
            $0.failedAttempts = 1
            $0.isRefreshing = false
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.pollingTick)

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            $0.failedAttempts = 2
        }
    }
}

// MARK: - Helpers

@MainActor
private func makeStore(
    clock: TestClock<Duration>,
    repository: TorrentRepository,
    preferences: UserPreferences
) -> TestStoreOf<TorrentListReducer> {
    let server = ServerConfig.previewLocalHTTP
    let environment = ServerConnectionEnvironment.testEnvironment(
        server: server,
        torrentRepository: repository
    )

    return TestStoreFactory.make(
        initialState: {
            var state = TorrentListReducer.State()
            state.connectionEnvironment = environment
            return state
        }(),
        reducer: { TorrentListReducer() },
        configure: { dependencies in
            dependencies.appClock = .test(clock: clock)
            dependencies.userPreferencesRepository = .testValue(preferences: preferences)
        }
    )
}

extension UserPreferencesRepository {
    fileprivate static func testValue(preferences: UserPreferences) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences }
        )
    }
}
