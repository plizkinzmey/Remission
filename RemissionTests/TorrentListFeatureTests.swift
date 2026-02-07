import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Torrent List Feature Tests")
@MainActor
struct TorrentListFeatureTests {
    let serverID = ServerConnectionEnvironment.testServerID

    // MARK: - Happy Path: Initial Load & Polling

    @Test("Initial load success and polling start")
    func testTask_InitialLoad_Success() async {
        let clock = TestClock()
        let torrents = [Torrent.previewDownloading, Torrent.previewCompleted]

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: .previewValue
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.userPreferencesRepository.loadClosure = { @Sendable _ in .default }
            $0.userPreferencesRepository.observeClosure = { @Sendable _ in
                AsyncStream {
                    $0.yield(.default)
                    $0.finish()
                }
            }
            $0.torrentRepository.fetchListClosure = { @Sendable in torrents }
        }
        store.exhaustivity = .off

        await store.send(TorrentListReducer.Action.task)

        await store.receive(TorrentListReducer.Action.userPreferencesResponse(.success(.default))) {
            $0.hasLoadedPreferences = true
        }

        await store.receive(\.torrentsResponse.success) {
            $0.phase = .loaded
            $0.isAwaitingConnection = false
        }

        // Verify polling tick after interval
        await clock.advance(by: .seconds(5) + .milliseconds(100))
        await store.receive(TorrentListReducer.Action.pollingTick)

        await store.finish()
    }

    // MARK: - Search & Filtering

    @Test("Search and filtering by status and category")
    func testSearchAndFiltering() async {
        let torrents = [
            Torrent.sampleDownloading(),
            Torrent.sampleSeeding(),
            Torrent.samplePaused()
        ]

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                phase: .loaded,
                items: IdentifiedArray(
                    uniqueElements: torrents.map { TorrentListItem.State(torrent: $0) })
            ),
            reducer: TorrentListReducer()
        )
        store.exhaustivity = .off

        // Test Search
        await store.send(TorrentListReducer.Action.searchQueryChanged("Ubuntu")) {
            $0.searchQuery = "Ubuntu"
        }
        #expect(store.state.visibleItems.count == 1)

        await store.send(TorrentListReducer.Action.searchQueryChanged("")) {
            $0.searchQuery = ""
        }
        #expect(store.state.visibleItems.count == 3)

        // Test Status Filtering
        await store.send(TorrentListReducer.Action.filterChanged(.downloading)) {
            $0.selectedFilter = .downloading
        }
        #expect(store.state.visibleItems.count == 1)

        await store.send(TorrentListReducer.Action.filterChanged(.all))

        // Test Category Filtering
        await store.send(TorrentListReducer.Action.categoryChanged(.programs))
        #expect(store.state.visibleItems.isEmpty)

        var torrentWithTag = torrents[0]
        torrentWithTag.tags.append("programs")

        let payload = TorrentListReducer.FetchSuccess(
            torrents: [torrentWithTag, torrents[1], torrents[2]],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(TorrentListReducer.Action.torrentsResponse(.success(payload)))
        #expect(store.state.visibleItems.count == 1)
    }

    @Test("UI Controls remain accessible when filtered list is empty but total items exist")
    func testControlVisibilityWithEmptyFilteredList() async {
        let torrent = Torrent.sampleDownloading()
        // Изначально торрент без тегов (категория 'other' или 'all')

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                phase: .loaded,
                items: [TorrentListItem.State(torrent: torrent)],
                selectedCategory: .programs  // Выбираем категорию, которой нет
            ),
            reducer: TorrentListReducer()
        )

        // 1. Проверяем, что видимый список пуст
        #expect(store.state.visibleItems.isEmpty)

        // 2. Проверяем, что общий список НЕ пуст (это условие для показа поиска и категорий)
        #expect(!store.state.items.isEmpty)

        // 3. Имитируем смену категории обратно на 'all'
        await store.send(.categoryChanged(.all)) {
            $0.selectedCategory = .all
        }

        // 4. Теперь список должен стать непустым
        #expect(!store.state.visibleItems.isEmpty)
    }

    // MARK: - Commands & Removal

    @Test("Torrent removal with confirmation")
    func testRemovalFlow() async throws {
        let torrent = Torrent.sampleDownloading()
        let clock = TestClock()
        let environment = makeEnvironment(
            torrentRepository: makeRemovalRepository(torrent: torrent)
        )
        let expectedSummary = try #require(
            StorageSummary.calculate(torrents: [], session: .previewActive, updatedAt: nil)
        )
        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: environment,
                phase: .loaded,
                items: [TorrentListItem.State(torrent: torrent)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(TorrentListReducer.Action.removeTapped(torrent.id)) {
            $0.pendingRemoveTorrentID = torrent.id
        }

        await store.send(TorrentListReducer.Action.removeConfirmation(.presented(.deleteWithData)))
        {
            $0.removingTorrentIDs = [torrent.id]
        }

        await store.receive(TorrentListReducer.Action.commandResponse(torrent.id, .success(true)))
        await store.receive(TorrentListReducer.Action.commandRefreshRequested)
        await store.receive(TorrentListReducer.Action.storageUpdated(expectedSummary)) {
            $0.storageSummary = expectedSummary
        }
        await store.receive(\.torrentsResponse.success) {
            $0.items = []
            $0.removingTorrentIDs = []
        }

        await store.send(.teardown)
        await store.finish()
    }

    // MARK: - Error Handling & Offline

    @Test("Fetch failure with exponential backoff")
    func testFetchFailure_Backoff() async {
        let clock = TestClock()
        let error = NSError(
            domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
        let environment = makeEnvironment(
            torrentRepository: makeFailingFetchRepository(error: error)
        )

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: environment,
                phase: .loaded
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(TorrentListReducer.Action.refreshRequested)
        await store.receive(\.torrentsResponse.failure) {
            $0.failedAttempts = 1
        }

        await clock.advance(by: .seconds(1) + .milliseconds(100))
        await store.receive(TorrentListReducer.Action.pollingTick)
        await store.receive(\.torrentsResponse.failure) {
            $0.failedAttempts = 2
        }
        await store.send(.teardown)
        await store.finish()
    }

    @Test("Handling seed ratio policy on refresh")
    func testSeedRatioPolicy() async {
        let clock = TestClock()
        var torrent = Torrent.sampleSeeding()
        torrent.summary.progress.uploadRatio = 2.5

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: .previewValue,
                phase: .loaded,
                items: [TorrentListItem.State(torrent: torrent)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.sessionRepository.fetchStateClosure = { @Sendable in
                var state = SessionState.previewActive
                state.seedRatioLimit = .init(isEnabled: true, value: 2.0)
                return state
            }
            $0.torrentRepository.fetchListClosure = { @Sendable [torrent] in [torrent] }
            $0.torrentRepository.stopClosure = { @Sendable [torrent] ids in
                #expect(ids == [torrent.id])
            }
        }
        store.exhaustivity = .off

        await store.send(TorrentListReducer.Action.refreshRequested)

        await store.skipReceivedActions()
        await store.finish()
    }

    // MARK: - Integration Flow

    @Test("Full flow from task to command and refresh")
    func testIntegration_FullFlow() async {
        let serverID = ServerConnectionEnvironment.testServerID
        let userPrefs = UserPreferencesRepository.previewValue
        let torrentRepo = TorrentRepository.previewValue

        let store = TestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: ServerConnectionEnvironment.previewValue
            )
        ) {
            TorrentListReducer()
        } withDependencies: {
            $0.appClock = .test(clock: TestClock())
            $0.userPreferencesRepository = userPrefs
            $0.torrentRepository = torrentRepo
            $0.mainQueue = .immediate
        }
        store.exhaustivity = .off

        await store.send(TorrentListReducer.Action.task)

        await store.receive(TorrentListReducer.Action.userPreferencesResponse(.success(.default))) {
            $0.hasLoadedPreferences = true
        }

        await store.receive(\.torrentsResponse.success)

        let downloadingID = Torrent.previewDownloading.id
        await store.send(TorrentListReducer.Action.pauseTapped(downloadingID))

        await store.skipReceivedActions()
        #expect(store.state.inFlightCommands.isEmpty)

        await store.finish()
    }

    @Test("Transition to offline state manually")
    func testGoOffline() async {
        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                phase: .loaded,
                items: [TorrentListItem.State(torrent: .previewDownloading)]
            ),
            reducer: TorrentListReducer()
        )
        store.exhaustivity = .off

        await store.send(TorrentListReducer.Action.goOffline(message: "No internet")) {
            $0.phase = .offline(.init(message: "No internet", lastUpdatedAt: nil))
            $0.items = []
        }

        await store.receive(
            TorrentListReducer.Action.errorPresenter(
                .showBanner(message: "No internet", retry: .refresh)))
        await store.finish()
    }

    private func makeEnvironment(
        torrentRepository: TorrentRepository
    ) -> ServerConnectionEnvironment {
        ServerConnectionEnvironment.testEnvironment(
            server: makeServer(),
            torrentRepository: torrentRepository,
            sessionRepository: .placeholder
        )
    }

    private func makeServer() -> ServerConfig {
        ServerConfig(
            id: serverID,
            name: "Test Server",
            connection: .init(host: "localhost", port: 9091),
            security: .http,
            authentication: .init(username: "admin"),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private func makeRemovalRepository(torrent: Torrent) -> TorrentRepository {
        var repository = TorrentRepository.testValue
        repository.removeClosure = { @Sendable ids, deleteData in
            #expect(ids == [torrent.id])
            #expect(deleteData == true)
        }
        repository.fetchListClosure = { @Sendable in [] }
        return repository
    }

    private func makeFailingFetchRepository(error: NSError) -> TorrentRepository {
        var repository = TorrentRepository.testValue
        repository.fetchListClosure = { @Sendable in throw error }
        return repository
    }
}
