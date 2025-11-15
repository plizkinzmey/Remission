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
        let environment = makeEnvironment(repository: repository)
        let store = TestStoreFactory.make(
            initialState: .init(
                torrentID: .init(rawValue: 1),
                connectionEnvironment: environment
            ),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { Date(timeIntervalSince1970: 5) }
            }
        )

        await store.send(.task) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.detailsResponse(.failure(APIError.networkUnavailable))) {
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
        let environment = makeEnvironment(repository: repository)
        let store = TestStoreFactory.make(
            initialState: .init(
                torrentID: torrent.id,
                connectionEnvironment: environment
            ),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.task) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        await store.send(.task)

        await clock.advance(by: .seconds(1))

        await store.receive(
            .detailsResponse(
                .success(.init(torrent: torrent, timestamp: timestamp))
            )
        ) {
            $0.isLoading = false
            assign(&$0, from: torrent)
            $0.speedHistory.samples = [
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
        let environment = makeEnvironment(repository: repository)

        let store = TestStoreFactory.make(
            initialState: .init(
                torrentID: torrent.id,
                connectionEnvironment: environment
            ),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.startTapped)
        await store.receive(.commandDidFinish("Торрент запущен")) {
            $0.alert = .info(message: "Торрент запущен")
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        var expected = torrent
        expected.status = .downloading
        await store.receive(
            .detailsResponse(
                .success(.init(torrent: expected, timestamp: timestamp))
            )
        ) {
            $0.isLoading = false
            assign(&$0, from: expected)
            $0.speedHistory.samples = [
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
        let environment = makeEnvironment(repository: repository)
        let store = TestStoreFactory.make(
            initialState: .init(
                torrentID: .init(rawValue: 1),
                connectionEnvironment: environment
            ),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
            }
        )

        await store.send(.startTapped)
        await store.receive(.commandFailed("Сеть недоступна")) {
            $0.alert = .error(message: "Сеть недоступна")
        }
    }

    @Test
    func toggleDownloadLimitUpdatesState() async {
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 1)
        torrent.summary.transfer.downloadLimit = .init(isEnabled: true, kilobytesPerSecond: 256)
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 30)
        let environment = makeEnvironment(repository: repository)

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentDetailReducer.State(
                    torrentID: torrent.id,
                    connectionEnvironment: environment
                )
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
        await store.receive(.commandDidFinish("Настройки скоростей обновлены")) {
            $0.alert = .info(message: "Настройки скоростей обновлены")
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        var expected = torrent
        expected.summary.transfer.downloadLimit = .init(isEnabled: true, kilobytesPerSecond: 512)
        await store.receive(
            .detailsResponse(
                .success(.init(torrent: expected, timestamp: timestamp))
            )
        ) {
            $0.isLoading = false
            assign(&$0, from: expected)
            $0.speedHistory.samples = [
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
        let environment = makeEnvironment(repository: repository)

        let store = TestStoreFactory.make(
            initialState: .init(
                torrentID: torrent.id,
                connectionEnvironment: environment
            ),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.priorityChanged(fileIndices: [0], priority: 2))
        await store.receive(.commandDidFinish("Приоритет обновлён")) {
            $0.alert = .info(message: "Приоритет обновлён")
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorMessage = nil
        }
        var expected = torrent
        expected.details?.files[0].priority = TorrentRepository.FilePriority.high.rawValue
        await store.receive(
            .detailsResponse(
                .success(.init(torrent: expected, timestamp: timestamp))
            )
        ) {
            $0.isLoading = false
            assign(&$0, from: expected)
            $0.speedHistory.samples = [
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
    state.peers = IdentifiedArray(uniqueElements: torrent.summary.peers.sources)

    if let details = torrent.details {
        state.downloadDir = details.downloadDirectory
        if let addedDate = details.addedDate {
            state.dateAdded = Int(addedDate.timeIntervalSince1970)
        } else {
            state.dateAdded = 0
        }
        state.files = IdentifiedArray(uniqueElements: details.files)
        state.trackers = IdentifiedArray(uniqueElements: details.trackers)
        state.trackerStats = IdentifiedArray(uniqueElements: details.trackerStats)
    } else {
        state.files = []
        state.trackers = []
        state.trackerStats = []
        state.downloadDir = ""
        state.dateAdded = 0
    }
}

private func makeEnvironment(
    repository: TorrentRepository
) -> ServerConnectionEnvironment {
    ServerConnectionEnvironment.testEnvironment(
        server: .previewLocalHTTP,
        torrentRepository: repository
    )
}
