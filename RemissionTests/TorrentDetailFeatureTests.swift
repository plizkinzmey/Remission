import Clocks
import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
@Suite("TorrentDetailReducer")
struct TorrentDetailFeatureTests {
    @Test
    func loadTorrentDetailsFailure() async {
        let repository = TorrentRepository.test(
            fetchDetails: { _ in throw APIError.networkUnavailable }
        )
        let store = TestStoreFactory.make(
            initialState: .init(torrentId: 1),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { Date(timeIntervalSince1970: 5) }
            }
        )

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.loadingFailed("Сеть недоступна")) {
            $0.isLoading = false
            $0.errorMessage = "Сеть недоступна"
        }
    }

    @Test
    func loadTorrentDetailsCancelsInFlightRequests() async throws {
        let clock = TestClock()
        let torrent = DomainFixtures.torrentDownloading
        let repository = TorrentRepository.test(
            fetchDetails: { identifier in
                try await clock.sleep(for: .seconds(1))
                guard identifier == torrent.id else {
                    throw InMemoryTorrentRepositoryError.torrentNotFound(identifier)
                }
                return torrent
            }
        )

        let timestamp = Date(timeIntervalSince1970: 10)
        let store = TestStoreFactory.make(
            initialState: .init(torrentId: torrent.id.rawValue),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.send(.loadTorrentDetails)

        await clock.advance(by: .seconds(1))

        await store.receive(.detailsLoaded(torrent, timestamp)) {
            $0.isLoading = false
            assign(&$0, from: torrent)
            $0.speedHistory = [
                SpeedSample(
                    timestamp: timestamp,
                    downloadRate: torrent.summary.transfer.downloadRate,
                    uploadRate: torrent.summary.transfer.uploadRate
                )
            ]
        }
    }

    @Test
    func startTorrentSuccess() async {
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 1)
        torrent.status = .stopped
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 20)

        let store = TestStoreFactory.make(
            initialState: .init(torrentId: torrent.id.rawValue),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.startTorrent)
        await store.receive(.actionCompleted("Торрент запущен"))
        await store.receive(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        var expected = torrent
        expected.status = .downloading
        await store.receive(.detailsLoaded(expected, timestamp)) {
            $0.isLoading = false
            assign(&$0, from: expected)
            $0.speedHistory = [
                SpeedSample(
                    timestamp: timestamp,
                    downloadRate: expected.summary.transfer.downloadRate,
                    uploadRate: expected.summary.transfer.uploadRate
                )
            ]
        }
    }

    @Test
    func startTorrentFailure() async {
        let repository = TorrentRepository.test(
            start: { _ in throw APIError.networkUnavailable }
        )
        let store = TestStoreFactory.make(
            initialState: .init(torrentId: 1),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.startTorrent)
        await store.receive(.actionFailed("Сеть недоступна"))
    }

    @Test
    func toggleDownloadLimitUpdatesState() async {
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 1)
        torrent.summary.transfer.downloadLimit = .init(isEnabled: true, kilobytesPerSecond: 256)
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 30)

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentDetailReducer.State(torrentId: torrent.id.rawValue)
                state.downloadLimit = 512
                state.downloadLimited = false
                return state
            }(),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.toggleDownloadLimit(true)) {
            $0.downloadLimited = true
        }
        await store.receive(.actionCompleted("Настройки скоростей обновлены"))
        await store.receive(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        var expected = torrent
        expected.summary.transfer.downloadLimit = .init(isEnabled: true, kilobytesPerSecond: 512)
        await store.receive(.detailsLoaded(expected, timestamp)) {
            $0.isLoading = false
            assign(&$0, from: expected)
            $0.speedHistory = [
                SpeedSample(
                    timestamp: timestamp,
                    downloadRate: expected.summary.transfer.downloadRate,
                    uploadRate: expected.summary.transfer.uploadRate
                )
            ]
        }
    }

    @Test
    func setPriorityUpdatesFiles() async throws {
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 1)
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 40)

        let store = TestStoreFactory.make(
            initialState: .init(torrentId: torrent.id.rawValue),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.setPriority(fileIndices: [0], priority: 2))
        await store.receive(.actionCompleted("Приоритет установлен"))
        await store.receive(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        var expected = torrent
        expected.details?.files[0].priority = TorrentRepository.FilePriority.high.rawValue
        await store.receive(.detailsLoaded(expected, timestamp)) {
            $0.isLoading = false
            assign(&$0, from: expected)
            $0.speedHistory = [
                SpeedSample(
                    timestamp: timestamp,
                    downloadRate: expected.summary.transfer.downloadRate,
                    uploadRate: expected.summary.transfer.uploadRate
                )
            ]
        }
    }
}

private func assign(
    _ state: inout TorrentDetailReducer.State,
    from torrent: Torrent
) {
    state.name = torrent.name
    state.status = torrent.status.rawValue
    state.percentDone = torrent.summary.progress.percentDone
    state.totalSize = torrent.summary.progress.totalSize
    state.downloadedEver = torrent.summary.progress.downloadedEver
    state.uploadedEver = torrent.summary.progress.uploadedEver
    state.uploadRatio = torrent.summary.progress.uploadRatio
    state.eta = torrent.summary.progress.etaSeconds

    state.rateDownload = torrent.summary.transfer.downloadRate
    state.rateUpload = torrent.summary.transfer.uploadRate
    state.downloadLimit = torrent.summary.transfer.downloadLimit.kilobytesPerSecond
    state.downloadLimited = torrent.summary.transfer.downloadLimit.isEnabled
    state.uploadLimit = torrent.summary.transfer.uploadLimit.kilobytesPerSecond
    state.uploadLimited = torrent.summary.transfer.uploadLimit.isEnabled

    state.peersConnected = torrent.summary.peers.connected
    state.peersFrom = torrent.summary.peers.sources

    if let details = torrent.details {
        state.downloadDir = details.downloadDirectory
        if let addedDate = details.addedDate {
            state.dateAdded = Int(addedDate.timeIntervalSince1970)
        } else {
            state.dateAdded = 0
        }
        state.files = details.files
        state.trackers = details.trackers
        state.trackerStats = details.trackerStats
    } else {
        state.files = []
        state.trackers = []
        state.trackerStats = []
        state.downloadDir = ""
        state.dateAdded = 0
    }
}
