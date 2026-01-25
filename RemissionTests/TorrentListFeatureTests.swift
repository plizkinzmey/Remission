import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Torrent List Feature Tests")
@MainActor
struct TorrentListFeatureTests {
    let serverID = UUID()

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

        await store.send(TorrentListReducer.Action.task) {
            $0.phase = .loading
            $0.cacheKey = ServerConnectionEnvironment.previewValue.cacheKey
        }

        await store.receive(TorrentListReducer.Action.userPreferencesResponse(.success(.default))) {
            $0.pollingInterval = .seconds(5)
            $0.isPollingEnabled = true
            $0.hasLoadedPreferences = true
        }

        await store.receive(\.torrentsResponse.success) {
            $0.items = [
                TorrentListItem.State(torrent: torrents[0]),
                TorrentListItem.State(torrent: torrents[1])
            ]
            $0.phase = .loaded
            $0.isAwaitingConnection = false
        }

        await store.receive(\.storageUpdated)

        // Verify polling tick after interval
        await clock.advance(by: .seconds(5))
        await store.receive(TorrentListReducer.Action.pollingTick)

        await store.send(TorrentListReducer.Action.teardown) {
            $0.isRefreshing = false
            $0.hasLoadedPreferences = false
        }
    }

    // MARK: - Search & Filtering

    @Test("Search and filtering by status and category")
    func testSearchAndFiltering() async {
        // "Ubuntu 25.04 Desktop", status: .downloading, tags: ["iso", "linux"]
        let torrents = [
            Torrent.sampleDownloading(),
            // "Fedora 41 Workstation", status: .seeding, tags: ["series", "video"]
            Torrent.sampleSeeding(),
            // "Arch Linux Snapshot", status: .stopped, tags: ["iso", "linux"]
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
        #expect(store.state.visibleItems[0].torrent.status == .downloading)

        await store.send(TorrentListReducer.Action.filterChanged(.all)) {
            $0.selectedFilter = .all
        }

        // Test Category Filtering
        await store.send(TorrentListReducer.Action.categoryChanged(.programs)) {
            $0.selectedCategory = .programs
        }
        #expect(store.state.visibleItems.isEmpty)

        // Mock update with category tag
        var torrentWithTag = torrents[0]
        torrentWithTag.tags.append("programs")

        let payload = TorrentListReducer.State.FetchSuccess(
            torrents: [torrentWithTag, torrents[1], torrents[2]],
            isFromCache: false,
            snapshotDate: nil
        )

        await store.send(TorrentListReducer.Action.torrentsResponse(.success(payload))) {
            $0.items[id: torrentWithTag.id]?.torrent.tags = ["iso", "linux", "programs"]
            $0.phase = .loaded
        }
        #expect(store.state.visibleItems.count == 1)
    }

    // MARK: - Commands & Removal

    @Test("Torrent removal with confirmation")
    func testRemovalFlow() async {
        let torrent = Torrent.sampleDownloading()
        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: .previewValue,
                phase: .loaded,
                items: [TorrentListItem.State(torrent: torrent)]
            ),
            reducer: TorrentListReducer()
        ) {
            $0.torrentRepository.removeClosure = { @Sendable ids, deleteData in
                #expect(ids == [torrent.id])
                #expect(deleteData == true)
            }
            $0.torrentRepository.fetchListClosure = { @Sendable in [] }
        }

        await store.send(TorrentListReducer.Action.removeTapped(torrent.id)) {
            $0.pendingRemoveTorrentID = torrent.id
            $0.removeConfirmation = .removeTorrent(name: torrent.name)
        }

        await store.send(TorrentListReducer.Action.removeConfirmation(.presented(.deleteWithData)))
        {
            $0.removeConfirmation = nil
            $0.pendingRemoveTorrentID = nil
            $0.removingTorrentIDs = [torrent.id]
            $0.items[id: torrent.id]?.isRemoving = true
            $0.inFlightCommands[torrent.id] = .init(
                command: .remove(deleteData: true), initialStatus: .downloading)
        }

        await store.receive(\.commandResponse)
        await store.receive(TorrentListReducer.Action.commandRefreshRequested)

        await store.receive(\.torrentsResponse.success) {
            $0.items = []
            $0.removingTorrentIDs = []
            $0.inFlightCommands.removeAll()
        }
        await store.receive(\.storageUpdated)
    }

    // MARK: - Error Handling & Offline

    @Test("Fetch failure with exponential backoff")
    func testFetchFailure_Backoff() async {
        let clock = TestClock()
        let error = NSError(
            domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])

        let store = TestStoreFactory.makeTestStore(
            initialState: TorrentListReducer.State(
                serverID: serverID,
                connectionEnvironment: .previewValue,
                phase: .loaded
            ),
            reducer: TorrentListReducer()
        ) {
            $0.appClock = .test(clock: clock)
            $0.torrentRepository.fetchListClosure = { @Sendable in throw error }
        }

        await store.send(TorrentListReducer.Action.refreshRequested) {
            $0.isRefreshing = true
        }

        await store.receive(\.torrentsResponse.failure) {
            $0.isRefreshing = false
            $0.failedAttempts = 1
            let offline = TorrentListReducer.State.OfflineState(
                message: "Network error", lastUpdatedAt: nil)
            $0.offlineState = offline
            $0.phase = .offline(offline)
            $0.errorPresenter.banner = .init(message: "Network error", retry: .refresh)
        }

        await clock.advance(by: .seconds(1))
        await store.receive(TorrentListReducer.Action.pollingTick)

        await store.receive(\.torrentsResponse.failure) {
            $0.failedAttempts = 2
        }
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
                var state = SessionState.preview
                state.seedRatioLimit = .init(isEnabled: true, value: 2.0)
                return state
            }
            $0.torrentRepository.fetchListClosure = { @Sendable in [torrent] }
            $0.torrentRepository.stopClosure = { @Sendable ids in
                #expect(ids == [torrent.id])
            }
        }

        await store.send(TorrentListReducer.Action.refreshRequested) {
            $0.isRefreshing = true
        }

        await store.receive(\.torrentsResponse.success) {
            $0.isRefreshing = false
        }
        await store.receive(\.storageUpdated)
    }

    // MARK: - Integration Flow

    @Test("Full flow from task to command and refresh")
    func testIntegration_FullFlow() async {
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

        await store.send(TorrentListReducer.Action.task) {
            $0.phase = .loading
            $0.cacheKey = ServerConnectionEnvironment.previewValue.cacheKey
        }

        await store.receive(TorrentListReducer.Action.userPreferencesResponse(.success(.default))) {
            $0.hasLoadedPreferences = true
            $0.isPollingEnabled = true
            $0.pollingInterval = .seconds(5)
        }

        await store.receive(\.torrentsResponse.success) {
            $0.items = [
                TorrentListItem.State(torrent: .previewDownloading),
                TorrentListItem.State(torrent: .previewCompleted)
            ]
            $0.phase = .loaded
            $0.isAwaitingConnection = false
        }
        await store.receive(\.storageUpdated)

        let downloadingID = Torrent.previewDownloading.id
        await store.send(TorrentListReducer.Action.pauseTapped(downloadingID)) {
            $0.inFlightCommands[downloadingID] = .init(command: .pause, initialStatus: .downloading)
        }

        await store.receive(\.commandResponse)
        await store.receive(TorrentListReducer.Action.commandRefreshRequested)
        await store.receive(\.torrentsResponse.success) {
            $0.inFlightCommands.removeAll()
        }
        await store.receive(\.storageUpdated)
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

        await store.send(TorrentListReducer.Action.goOffline(message: "No internet")) {
            let offline = TorrentListReducer.State.OfflineState(
                message: "No internet", lastUpdatedAt: nil)
            $0.offlineState = offline
            $0.phase = .offline(offline)
            $0.items = []
            $0.errorPresenter.banner = .init(message: "No internet", retry: .refresh)
        }
    }
}
