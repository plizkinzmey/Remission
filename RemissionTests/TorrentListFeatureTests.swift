import Clocks
import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length type_body_length

@Suite("TorrentListReducer")
@MainActor
struct TorrentListFeatureTests {
    // Проверяем, что happy path загружает данные и перезапускает polling по таймеру.
    @Test("task загружает торренты и запускает polling c TestClock")
    func taskLoadsTorrentsAndStartsPolling() async {
        let clock = TestClock<Duration>()
        let torrents = TorrentFixture.torrentListSample
        #expect(torrents.isEmpty == false)
        let repository = TorrentRepository.test(fetchList: { torrents })
        let preferences = DomainFixtures.userPreferences

        let store = makeStore(
            clock: clock,
            repository: repository,
            preferences: preferences
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.isPollingEnabled = preferences.isAutoRefreshEnabled
        }

        let expectedItems = IdentifiedArray(
            uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
        )

        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
            $0.phase = .loaded
            $0.items = expectedItems
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        let interval = Duration.milliseconds(Int(preferences.pollingInterval * 1_000))
        await clock.advance(by: interval)

        await store.receive(.pollingTick)
        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
            $0.items = expectedItems
            $0.failedAttempts = 0
        }
    }

    @Test("task подтягивает кешированный снимок при офлайне")
    func taskRestoresCachedSnapshotOffline() async {
        let server = ServerConfig.previewLocalHTTP
        let now = Date(timeIntervalSince1970: 500)
        let cache = ServerSnapshotCache.inMemory(now: { now })
        let client = cache.client(server.id)
        _ = try? await client.updateTorrents(DomainFixtures.torrents)

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentListReducer.State()
                state.serverID = server.id
                state.phase = .loading
                return state
            }(),
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.serverSnapshotCache = cache
            }
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.receive(.restoreCachedSnapshot)
        await store.receive(
            .torrentsResponse(
                .success(
                    makeFetchSuccess(DomainFixtures.torrents, isFromCache: true, snapshotDate: now))
            )
        ) {
            $0.items = IdentifiedArray(
                uniqueElements: DomainFixtures.torrents.map { TorrentListItem.State(torrent: $0) }
            )
            $0.lastSnapshotAt = now
            $0.phase = .loaded
        }
    }

    @Test("polling interval читает значение из UserPreferences")
    func pollingIntervalRespectsUserPreferences() async {
        var preferences = DomainFixtures.userPreferences
        preferences.pollingInterval = 1.5
        let preferencesOverride = preferences

        let baseClock = TestClock<Duration>()
        let recordingClock = RecordingClock(base: baseClock)

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentListReducer.State()
                state.connectionEnvironment = .preview(server: .previewLocalHTTP)
                state.serverID = ServerConfig.previewLocalHTTP.id
                return state
            }(),
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: recordingClock)
                dependencies.userPreferencesRepository = .testValue(
                    preferences: preferencesOverride)
                dependencies.torrentRepository = TorrentRepository.test(fetchList: {
                    DomainFixtures.torrents
                })
            }
        )
        store.exhaustivity = .off

        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(1_500)
            $0.isPollingEnabled = preferences.isAutoRefreshEnabled
        }

        await store.send(.torrentsResponse(.success(makeFetchSuccess(DomainFixtures.torrents)))) {
            $0.phase = .loaded
            $0.items = IdentifiedArray(
                uniqueElements: DomainFixtures.torrents.map {
                    TorrentListItem.State(torrent: $0)
                }
            )
            $0.isRefreshing = false
            $0.failedAttempts = 0
        }

        await Task.yield()
        #expect(recordingClock.sleepHistory.first == .milliseconds(1_500))

        await store.send(.teardown)
    }

    // Проверяем, что server-scoped окружение переопределяет глобальные зависимости.
    @Test("ServerConnectionEnvironment применяется перед fetchList")
    func serverEnvironmentOverridesGlobalDependencies() async {
        let clock = TestClock<Duration>()
        let defaultRepositoryCalls = FetchCounter()
        let scopedRepositoryCalls = FetchCounter()
        let torrents = TorrentFixture.torrentListSample
        #expect(torrents.isEmpty == false)
        let preferences = DomainFixtures.userPreferences

        let defaultRepository = TorrentRepository.test(fetchList: {
            await defaultRepositoryCalls.increment()
            return []
        })

        let scopedRepository = TorrentRepository.test(fetchList: {
            await scopedRepositoryCalls.increment()
            return torrents
        })

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: scopedRepository
        )

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentListReducer.State()
                state.connectionEnvironment = environment
                state.serverID = environment.serverID
                return state
            }(),
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.userPreferencesRepository = .testValue(preferences: preferences)
                dependencies.torrentRepository = defaultRepository
            }
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.isPollingEnabled = preferences.isAutoRefreshEnabled
        }

        let expectedItems = IdentifiedArray(
            uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
        )

        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
            $0.phase = .loaded
            $0.items = expectedItems
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        await store.send(.teardown)

        #expect(await defaultRepositoryCalls.value == 0)
        #expect(await scopedRepositoryCalls.value == 1)
    }

    // Проверяем, что ошибка запроса показывает alert и включает экспоненциальный backoff.
    @Test("ошибка fetchList показывает alert и использует экспоненциальный backoff")
    func errorPathShowsAlertAndBackoff() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "failed" }
        }

        let clock = TestClock<Duration>()
        let repository = TorrentRepository.test(fetchList: {
            throw DummyError.failed
        })
        let preferences = DomainFixtures.userPreferences

        let store = makeStore(
            clock: clock,
            repository: repository,
            preferences: preferences
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.isPollingEnabled = preferences.isAutoRefreshEnabled
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            let offline = TorrentListReducer.State.OfflineState(
                message: "failed",
                lastUpdatedAt: nil
            )
            $0.phase = .offline(offline)
            $0.offlineState = offline
            $0.alert = .networkError(message: "failed")
            $0.failedAttempts = 1
            $0.isRefreshing = false
        }

        await clock.advance(by: .seconds(1))
        await store.receive(.pollingTick)
        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            $0.failedAttempts = 2
            $0.offlineState?.message = "failed"
        }
    }

    @Test("manual refresh сбрасывает backoff перед повторным запросом")
    func manualRefreshResetsBackoff() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "failed" }
        }

        let clock = TestClock<Duration>()
        let repository = TorrentRepository.test(fetchList: {
            throw DummyError.failed
        })
        let preferences = DomainFixtures.userPreferences

        let store = makeStore(
            clock: clock,
            repository: repository,
            preferences: preferences
        )
        store.exhaustivity = .off

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.pollingInterval = .milliseconds(Int(preferences.pollingInterval * 1_000))
            $0.isPollingEnabled = preferences.isAutoRefreshEnabled
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            let offline = TorrentListReducer.State.OfflineState(
                message: "failed",
                lastUpdatedAt: nil
            )
            $0.phase = .offline(offline)
            $0.offlineState = offline
            $0.alert = .networkError(message: "failed")
            $0.failedAttempts = 1
            $0.isRefreshing = false
        }

        await store.send(.refreshRequested) {
            $0.alert = nil
            $0.failedAttempts = 0
            $0.isRefreshing = true
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            let offline = TorrentListReducer.State.OfflineState(
                message: "failed",
                lastUpdatedAt: nil
            )
            $0.offlineState = offline
            $0.phase = .offline(offline)
            $0.failedAttempts = 1
            $0.isRefreshing = false
        }
    }

    @Test("delegate detailUpdated обновляет список и инициирует мгновенный refresh")
    func detailDelegateUpdatesListAndRefreshes() async {
        let clock = TestClock<Duration>()
        let baseTorrent = DomainFixtures.torrentDownloading
        let updatedTorrent: Torrent = {
            var torrent = baseTorrent
            torrent.status = .seeding
            torrent.summary.progress.percentDone = 0.95
            return torrent
        }()

        let repository = TorrentRepository.test(fetchList: { [updatedTorrent] })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        var initialState = makeLoadedState(torrents: [baseTorrent])
        initialState.connectionEnvironment = environment
        initialState.isPollingEnabled = false

        let store = TestStoreFactory.make(
            initialState: initialState,
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.delegate(.detailUpdated(updatedTorrent))) {
            $0.items[id: updatedTorrent.id]?.update(with: updatedTorrent)
            $0.phase = .loaded
            $0.alert = nil
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        await store.receive(.torrentsResponse(.success(makeFetchSuccess([updatedTorrent])))) {
            $0.phase = .loaded
            $0.items = IdentifiedArray(
                uniqueElements: [TorrentListItem.State(torrent: updatedTorrent)]
            )
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }
    }

    @Test("delegate detailUpdated при ошибке показывает alert и не расходится со state")
    func detailDelegateHandlesErrorPath() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "failed" }
        }

        let clock = TestClock<Duration>()
        let baseTorrent = DomainFixtures.torrentDownloading
        let updatedTorrent: Torrent = {
            var torrent = baseTorrent
            torrent.status = .seeding
            return torrent
        }()

        let repository = TorrentRepository.test(fetchList: { throw DummyError.failed })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        var initialState = makeLoadedState(torrents: [baseTorrent])
        initialState.connectionEnvironment = environment
        initialState.isPollingEnabled = true

        let store = TestStoreFactory.make(
            initialState: initialState,
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.delegate(.detailUpdated(updatedTorrent))) {
            $0.items[id: updatedTorrent.id]?.update(with: updatedTorrent)
            $0.phase = .loaded
            $0.alert = nil
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            let offline = TorrentListReducer.State.OfflineState(
                message: "failed",
                lastUpdatedAt: nil
            )
            $0.offlineState = offline
            $0.alert = .networkError(message: "failed")
            $0.failedAttempts = 1
            $0.isRefreshing = false
            $0.phase = .offline(offline)
        }
    }

    @Test("delegate detailRemoved удаляет элемент и инициирует refresh")
    func detailDelegateHandlesRemoval() async {
        let clock = TestClock<Duration>()
        let torrents = [
            DomainFixtures.torrentDownloading,
            DomainFixtures.torrentSeeding
        ]
        let remaining = torrents[1]

        let repository = TorrentRepository.test(fetchList: { [remaining] })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        var initialState = makeLoadedState(torrents: torrents)
        initialState.connectionEnvironment = environment
        initialState.isPollingEnabled = false

        let store = TestStoreFactory.make(
            initialState: initialState,
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.delegate(.detailRemoved(torrents[0].id))) {
            $0.items.remove(id: torrents[0].id)
            $0.phase = .loaded
            $0.alert = nil
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        await store.receive(.torrentsResponse(.success(makeFetchSuccess([remaining])))) {
            $0.phase = .loaded
            $0.items = IdentifiedArray(
                uniqueElements: [TorrentListItem.State(torrent: remaining)]
            )
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }
    }

    @Test("delegate added оптимистично вставляет элемент и инициирует refresh")
    func addedDelegateInsertsAndRefreshes() async {
        let addResult = TorrentRepository.AddResult(
            status: .added,
            id: .init(rawValue: 999),
            name: "New Torrent",
            hashString: "hash-999"
        )
        let fetchedTorrent: Torrent = {
            var torrent = DomainFixtures.torrentDownloading
            torrent.id = addResult.id
            torrent.name = addResult.name
            return torrent
        }()

        let repository = TorrentRepository.test(fetchList: { [fetchedTorrent] })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        var initialState = TorrentListReducer.State()
        initialState.connectionEnvironment = environment
        initialState.isPollingEnabled = false
        initialState.serverID = environment.serverID

        let store = TestStoreFactory.make(
            initialState: initialState,
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.delegate(.added(addResult))) {
            $0.phase = .loaded
            $0.alert = nil
            $0.failedAttempts = 0
            $0.isRefreshing = false
            #expect($0.items[id: addResult.id]?.torrent.name == addResult.name)
            #expect($0.items[id: addResult.id]?.torrent.status == .downloadWaiting)
        }

        await store.receive(.torrentsResponse(.success(makeFetchSuccess([fetchedTorrent])))) {
            $0.phase = .loaded
            $0.items = IdentifiedArray(
                uniqueElements: [TorrentListItem.State(torrent: fetchedTorrent)]
            )
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }
    }

    @Test("delegate added при ошибке сохраняет placeholder и показывает alert")
    func addedDelegateHandlesError() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "failed" }
        }

        let addResult = TorrentRepository.AddResult(
            status: .added,
            id: .init(rawValue: 1001),
            name: "Broken Torrent",
            hashString: "hash-1001"
        )

        let repository = TorrentRepository.test(fetchList: { throw DummyError.failed })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        var initialState = TorrentListReducer.State()
        initialState.connectionEnvironment = environment
        initialState.isPollingEnabled = false

        let store = TestStoreFactory.make(
            initialState: initialState,
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.delegate(.added(addResult))) {
            $0.phase = .loaded
            $0.alert = nil
            $0.failedAttempts = 0
            $0.isRefreshing = false
            #expect($0.items[id: addResult.id]?.torrent.name == addResult.name)
            #expect($0.items[id: addResult.id]?.torrent.status == .downloadWaiting)
        }

        await store.receive(.torrentsResponse(.failure(DummyError.failed))) {
            let offline = TorrentListReducer.State.OfflineState(
                message: "failed",
                lastUpdatedAt: nil
            )
            $0.offlineState = offline
            $0.phase = .offline(offline)
            $0.alert = .networkError(message: "failed")
            $0.failedAttempts = 1
            $0.isRefreshing = false
        }
        #expect(store.state.items[id: addResult.id] != nil)
    }

    // Проверяем, что поиск и фильтры не инициируют дополнительный fetchList.
    @Test("searchQuery и filter меняют visibleItems без дополнительных запросов")
    func searchAndFilterUpdateVisibleItemsWithoutFetching() async {
        let torrents = DomainFixtures.torrentListSamples
        let fetchCounter = FetchCounter()

        let store = TestStoreFactory.make(
            initialState: makeLoadedState(torrents: torrents),
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = TorrentRepository.test(fetchList: {
                    await fetchCounter.increment()
                    return torrents
                })
            }
        )

        await store.send(.searchQueryChanged("Swift")) {
            $0.searchQuery = "Swift"
        }
        #expect(store.state.visibleItems.count == 1)
        #expect(store.state.visibleItems.first?.torrent.id == DomainFixtures.torrentSeeding.id)

        await store.send(.searchQueryChanged("")) {
            $0.searchQuery = ""
        }

        await store.send(.filterChanged(.errors)) {
            $0.selectedFilter = .errors
        }
        #expect(store.state.visibleItems.count == 1)
        #expect(store.state.visibleItems.first?.torrent.id == DomainFixtures.torrentErrored.id)

        let fetches = await fetchCounter.value
        #expect(fetches == 0, "Search/filter не должны триггерить fetchList")
    }

    // Проверяем, что ручной refresh отменяет предыдущий fetch и запускает новый.
    @Test("manual refresh отменяет предыдущий запрос и запускает новый")
    func manualRefreshCancelsInFlightRequest() async {
        let clock = TestClock<Duration>()
        let callCounter = FetchCounter()
        let cancellationRecorder = CancellationRecorder()
        let torrents = DomainFixtures.torrents

        let repository = TorrentRepository.test(fetchList: {
            let call = await callCounter.increment()
            if call == 1 {
                do {
                    try await clock.sleep(for: .seconds(5))
                } catch is CancellationError {
                    await cancellationRecorder.markCancelled(call)
                }
                throw CancellationError()
            } else {
                try await clock.sleep(for: .milliseconds(10))
            }
            return torrents
        })

        let store = makeStore(
            clock: clock,
            repository: repository,
            preferences: DomainFixtures.userPreferences
        )

        await store.send(.refreshRequested) {
            $0.isRefreshing = true
        }

        await clock.advance(by: .milliseconds(1))

        await store.send(.refreshRequested)

        await clock.advance(by: .milliseconds(10))

        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
            $0.phase = .loaded
            $0.items = IdentifiedArray(
                uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
            )
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        #expect(await cancellationRecorder.wasCancelled(call: 1))
        #expect(await callCounter.value == 2)
    }

    @Test("обновление настроек пересчитывает интервал и перезапускает fetch")
    func preferencesUpdateRestartsPolling() async {
        let clock = TestClock<Duration>()
        let torrents = TorrentFixture.torrentListSample
        #expect(torrents.isEmpty == false)
        let callCounter = FetchCounter()
        let basePreferences = DomainFixtures.userPreferences

        let repository = TorrentRepository.test(fetchList: {
            await callCounter.increment()
            return torrents
        })

        let userPreferencesRepository = UserPreferencesRepository(
            load: { basePreferences },
            updatePollingInterval: { _ in basePreferences },
            setAutoRefreshEnabled: { _ in basePreferences },
            setTelemetryEnabled: { _ in basePreferences },
            updateDefaultSpeedLimits: { _ in basePreferences },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )

        let server = ServerConfig.previewLocalHTTP
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            torrentRepository: repository
        )

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentListReducer.State()
                state.connectionEnvironment = environment
                state.serverID = environment.serverID
                return state
            }(),
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.userPreferencesRepository = userPreferencesRepository
            }
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.send(.userPreferencesResponse(.success(basePreferences))) {
            $0.pollingInterval = .milliseconds(Int(basePreferences.pollingInterval * 1_000))
            $0.isPollingEnabled = basePreferences.isAutoRefreshEnabled
        }

        let expectedItems = IdentifiedArray(
            uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
        )

        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
            $0.phase = .loaded
            $0.items = expectedItems
            $0.isRefreshing = false
            $0.failedAttempts = 0
        }

        #expect(await callCounter.value == 1)

        var updatedPreferences = basePreferences
        updatedPreferences.pollingInterval = 10
        updatedPreferences.isAutoRefreshEnabled = false

        await store.send(.userPreferencesResponse(.success(updatedPreferences))) {
            $0.pollingInterval = .seconds(10)
            $0.isPollingEnabled = false
        }

        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
            $0.items = expectedItems
            $0.failedAttempts = 0
            $0.isRefreshing = false
        }

        #expect(await callCounter.value == 2)
    }

    // Проверяем, что ошибка загрузки preferences показывает alert и всё равно запускает fetch.
    @Test("preferences failure показывает alert и запускает начальный fetch")
    func preferencesErrorShowsAlertAndFetches() async {
        enum PrefError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "preferences failed" }
        }

        let clock = TestClock<Duration>()
        let torrents = DomainFixtures.torrents
        let repository = TorrentRepository.test(fetchList: { torrents })
        let server = ServerConfig.previewLocalHTTP
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            torrentRepository: repository
        )

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentListReducer.State()
                state.connectionEnvironment = environment
                state.serverID = environment.serverID
                return state
            }(),
            reducer: { TorrentListReducer() },
            configure: { dependencies in
                dependencies.appClock = .test(clock: clock)
                dependencies.userPreferencesRepository = .failingLoad(error: PrefError.failed)
            }
        )

        await store.send(.task) {
            $0.phase = .loading
        }

        await store.send(.userPreferencesResponse(.failure(PrefError.failed))) {
            $0.alert = .preferencesError(message: "preferences failed")
        }

        await store.receive(.torrentsResponse(.success(makeFetchSuccess(torrents)))) {
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
            state.serverID = server.id
            return state
        }(),
        reducer: { TorrentListReducer() },
        configure: { dependencies in
            dependencies.appClock = .test(clock: clock)
            dependencies.userPreferencesRepository = .testValue(preferences: preferences)
        }
    )
}

private func makeLoadedState(torrents: [Torrent]) -> TorrentListReducer.State {
    var state = TorrentListReducer.State()
    state.connectionEnvironment = .preview(server: .previewLocalHTTP)
    state.serverID = ServerConfig.previewLocalHTTP.id
    state.phase = .loaded
    state.items = IdentifiedArray(
        uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) }
    )
    return state
}

private func makeFetchSuccess(
    _ torrents: [Torrent],
    isFromCache: Bool = false,
    snapshotDate: Date? = nil
) -> TorrentListReducer.State.FetchSuccess {
    TorrentListReducer.State.FetchSuccess(
        torrents: torrents,
        isFromCache: isFromCache,
        snapshotDate: snapshotDate
    )
}

private final class RecordingClock: Clock, @unchecked Sendable {
    typealias Duration = Swift.Duration
    typealias Instant = TestClock<Duration>.Instant

    private let base: TestClock<Duration>
    private(set) var sleepHistory: [Duration] = []

    init(base: TestClock<Duration>) {
        self.base = base
    }

    var now: Instant { base.now }
    var minimumResolution: Duration { base.minimumResolution }

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let interval = base.now.duration(to: deadline)
        sleepHistory.append(interval)
        try await base.sleep(until: deadline, tolerance: tolerance)
    }

    func sleep(for duration: Duration, tolerance: Duration? = nil) async throws {
        sleepHistory.append(duration)
        try await base.sleep(for: duration, tolerance: tolerance)
    }
}

extension UserPreferencesRepository {
    fileprivate static func testValue(preferences: UserPreferences) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { preferences },
            updatePollingInterval: { _ in preferences },
            setAutoRefreshEnabled: { _ in preferences },
            setTelemetryEnabled: { _ in preferences },
            updateDefaultSpeedLimits: { _ in preferences },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }

    fileprivate static func failingLoad(error: any Error) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: { throw error },
            updatePollingInterval: { interval in
                var prefs = DomainFixtures.userPreferences
                prefs.pollingInterval = interval
                return prefs
            },
            setAutoRefreshEnabled: { isEnabled in
                var prefs = DomainFixtures.userPreferences
                prefs.isAutoRefreshEnabled = isEnabled
                return prefs
            },
            setTelemetryEnabled: { isEnabled in
                var prefs = DomainFixtures.userPreferences
                prefs.isTelemetryEnabled = isEnabled
                return prefs
            },
            updateDefaultSpeedLimits: { limits in
                var prefs = DomainFixtures.userPreferences
                prefs.defaultSpeedLimits = limits
                return prefs
            },
            observe: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }
}
