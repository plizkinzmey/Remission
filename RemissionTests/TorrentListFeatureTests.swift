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

    @MainActor
    @Test("Кнопка добавления пробрасывает делегат addTorrentRequested")
    func addTorrentButtonDispatchesDelegate() async {
        let store = makeStore(
            clock: TestClock<Duration>(),
            repository: .test(fetchList: { [.previewDownloading] }),
            preferences: .default
        )

        await store.send(.addTorrentButtonTapped)
        await store.receive(.delegate(.addTorrentRequested))
    }

    @MainActor
    @Test("Поиск фильтрует visibleItems")
    func searchQueryFiltersVisibleItems() async {
        let store = TestStore(
            initialState: makeLoadedState(torrents: sampleTorrents)
        ) {
            TorrentListReducer()
        }

        await store.send(.searchQueryChanged("swift")) {
            $0.searchQuery = "swift"
        }

        #expect(store.state.visibleItems.count == 1)
        #expect(store.state.visibleItems.first?.torrent.name == "Swift Beta")
    }

    @MainActor
    @Test("Фильтр показывает только скачивающиеся торренты")
    func filterShowsOnlyDownloading() async {
        let store = TestStore(
            initialState: makeLoadedState(torrents: sampleTorrents)
        ) {
            TorrentListReducer()
        }

        await store.send(.filterChanged(.downloading)) {
            $0.selectedFilter = .downloading
        }

        #expect(store.state.visibleItems.count == 2)
        #expect(
            store.state.visibleItems.allSatisfy {
                [.downloading, .downloadWaiting, .checkWaiting, .checking]
                    .contains($0.torrent.status)
            }
        )
    }

    @MainActor
    @Test("Сортировка по прогрессу располагает элементы по убыванию прогресса")
    func sortByProgressOrdersItems() async {
        let store = TestStore(
            initialState: makeLoadedState(torrents: sampleTorrents)
        ) {
            TorrentListReducer()
        }

        await store.send(.sortChanged(.progress)) {
            $0.sortOrder = .progress
        }

        let names = store.state.visibleItems.map(\.torrent.name)
        #expect(names == ["Seedbox Archive", "Ubuntu ISO", "Swift Beta"])
    }

    @MainActor
    @Test("Ручное обновление включает индикатор и сбрасывается после ответа")
    func manualRefreshTogglesRefreshingFlag() async {
        let torrents: [Torrent] = [.previewDownloading]
        let repository = TorrentRepository.test(fetchList: { torrents })
        let store = makeStore(
            clock: TestClock<Duration>(),
            repository: repository,
            preferences: .default
        )

        await store.send(.refreshRequested) {
            $0.isRefreshing = true
        }

        await store.receive(.torrentsResponse(.success(torrents))) {
            $0.phase = .loaded
            $0.items = IdentifiedArray(
                uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
            )
            $0.failedAttempts = 0
            $0.isRefreshing = false
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

private let sampleTorrents: [Torrent] = [
    makeTorrent(
        id: 1,
        name: "Ubuntu ISO",
        status: .downloading,
        progress: 0.9,
        downloadRate: 3_000_000
    ),
    makeTorrent(
        id: 2,
        name: "Swift Beta",
        status: .downloading,
        progress: 0.45,
        downloadRate: 1_000_000
    ),
    makeTorrent(
        id: 3,
        name: "Seedbox Archive",
        status: .seeding,
        progress: 1.0,
        downloadRate: 0
    )
]

private func makeLoadedState(torrents: [Torrent]) -> TorrentListReducer.State {
    var state = TorrentListReducer.State()
    state.connectionEnvironment = .preview(server: .previewLocalHTTP)
    state.phase = .loaded
    state.items = IdentifiedArray(
        uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
    )
    return state
}

private func makeTorrent(
    id: Int,
    name: String,
    status: Torrent.Status,
    progress: Double,
    downloadRate: Int
) -> Torrent {
    let progressModel = Torrent.Progress(
        percentDone: progress,
        totalSize: 1_000_000_000,
        downloadedEver: Int(progress * 1_000_000_000),
        uploadedEver: Int(progress * 500_000_000),
        uploadRatio: 0.5,
        etaSeconds: progress >= 1 ? -1 : 3_600
    )
    let transfer = Torrent.Transfer(
        downloadRate: downloadRate,
        uploadRate: 200_000,
        downloadLimit: .init(isEnabled: false, kilobytesPerSecond: 0),
        uploadLimit: .init(isEnabled: false, kilobytesPerSecond: 0)
    )
    let peers = Torrent.Peers(connected: 5, sources: [])

    return Torrent(
        id: .init(rawValue: id),
        name: name,
        status: status,
        summary: .init(progress: progressModel, transfer: transfer, peers: peers)
    )
}
