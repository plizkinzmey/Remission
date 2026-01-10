// swiftlint:disable file_length
import Clocks
import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable file_length
@MainActor
@Suite("TorrentDetailReducer")
// swiftlint:disable:next type_body_length
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
            $0.errorPresenter.banner = nil
        }

        await store.receive(.detailsResponse(.failure(APIError.networkUnavailable))) {
            $0.isLoading = false
            $0.errorPresenter.banner = .init(
                message: L10n.tr("torrentDetail.api.networkUnavailable"),
                retry: .reloadDetails
            )
        }
    }

    @Test
    func loadTorrentDetailsUsesInjectedEnvironment() async {
        let torrent = DomainFixtures.torrentDownloading
        let environmentRepository = TorrentRepository.test(
            fetchDetails: { _ in torrent }
        )
        let failingRepository = TorrentRepository.test(
            fetchDetails: { _ in throw APIError.networkUnavailable }
        )
        let environment = makeEnvironment(repository: environmentRepository)
        let timestamp = Date(timeIntervalSince1970: 15)

        let store = TestStoreFactory.make(
            initialState: .init(
                torrentID: torrent.id,
                connectionEnvironment: environment
            ),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = failingRepository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.task) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
        }

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
            $0.errorPresenter.banner = nil
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
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )

        await store.send(.startTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .start
        }
        await store.receive(.commandResponse(.success(.start))) {
            $0.activeCommand = nil
        }
        await store.receive(.commandDidFinish(L10n.tr("torrentDetail.status.started"))) {
            $0.alert = .info(message: L10n.tr("torrentDetail.status.started"))
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
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
            $0.errorPresenter.banner = nil
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

        await store.send(.startTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .start
        }
        await store.receive(
            .commandResponse(
                .failure(
                    .start,
                    L10n.tr("torrentDetail.api.networkUnavailable")
                )
            )
        ) {
            $0.activeCommand = nil
        }
        await store.receive(.commandFailed(L10n.tr("torrentDetail.api.networkUnavailable"))) {
            $0.alert = .error(message: L10n.tr("torrentDetail.api.networkUnavailable"))
        }
    }

    @Test
    func pauseTorrentSuccess() async {
        var torrent = DomainFixtures.torrentDownloading
        torrent.status = .downloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 24)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )

        await store.send(.pauseTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .pause
        }
        await store.receive(.commandResponse(.success(.pause))) {
            $0.activeCommand = nil
        }
        await store.receive(.commandDidFinish(L10n.tr("torrentDetail.status.stopped"))) {
            $0.alert = .info(message: L10n.tr("torrentDetail.status.stopped"))
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
        }
        var expected = torrent
        expected.status = .stopped
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
            $0.errorPresenter.banner = nil
        }
    }

    @Test
    func pauseTorrentFailure() async throws {
        var torrent = DomainFixtures.torrentDownloading
        torrent.status = .downloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 25)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )
        await repositoryStore.markFailure(.stop)
        let expectedMessage = "InMemoryTorrentRepository operation stop marked as failed."

        await store.send(.pauseTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .pause
        }
        await store.receive(.commandResponse(.failure(.pause, expectedMessage))) {
            $0.activeCommand = nil
        }
        await store.receive(.commandFailed(expectedMessage)) {
            $0.alert = .error(message: expectedMessage)
        }
    }

    @Test
    func verifyCommandSuccess() async {
        var torrent = DomainFixtures.torrentDownloading
        torrent.status = .checkWaiting
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 30)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )

        await store.send(.verifyTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .verify
        }
        await store.receive(.commandResponse(.success(.verify))) {
            $0.activeCommand = nil
        }
        await store.receive(.commandDidFinish(L10n.tr("torrentDetail.status.verify"))) {
            $0.alert = .info(message: L10n.tr("torrentDetail.status.verify"))
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
        }
        var expected = torrent
        expected.status = .checking
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
            $0.errorPresenter.banner = nil
        }
    }

    @Test
    func verifyCommandFailure() async throws {
        let torrent = DomainFixtures.torrentDownloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 31)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )
        await repositoryStore.markFailure(.verify)
        let expectedMessage = "InMemoryTorrentRepository operation verify marked as failed."

        await store.send(.verifyTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .verify
        }
        await store.receive(.commandResponse(.failure(.verify, expectedMessage))) {
            $0.activeCommand = nil
        }
        await store.receive(.commandFailed(expectedMessage)) {
            $0.alert = .error(message: expectedMessage)
        }
    }

    @Test
    func toggleDownloadLimitUpdatesState() async {
        var torrent = DomainFixtures.torrentDownloading
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
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
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
            $0.errorPresenter.banner = nil
        }
    }

    @Test
    func toggleDownloadLimitOffPersists() async {
        var torrent = DomainFixtures.torrentDownloading
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
                state.downloadLimited = true
                return state
            }(),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.toggleDownloadLimit(false)) {
            $0.downloadLimited = false
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
        }
        var expected = torrent
        expected.summary.transfer.downloadLimit = .init(isEnabled: false, kilobytesPerSecond: 512)
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
            $0.errorPresenter.banner = nil
        }
    }

    @Test
    func toggleDownloadLimitOffFailureShowsError() async throws {
        let torrent = DomainFixtures.torrentDownloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 30)
        let environment = makeEnvironment(repository: repository)
        await repositoryStore.markFailure(.updateTransferSettings)

        let store = TestStoreFactory.make(
            initialState: {
                var state = TorrentDetailReducer.State(
                    torrentID: torrent.id,
                    connectionEnvironment: environment
                )
                state.downloadLimit = 512
                state.downloadLimited = true
                return state
            }(),
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies.torrentRepository = repository
                dependencies.dateProvider.now = { timestamp }
            }
        )

        await store.send(.toggleDownloadLimit(false)) {
            $0.downloadLimited = false
        }
        let message = "InMemoryTorrentRepository operation updateTransferSettings marked as failed."
        await store.receive(.commandFailed(message)) {
            $0.alert = .error(message: message)
        }
    }

    @Test
    func setPriorityUpdatesFiles() async throws {
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 1)
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 40)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )

        await store.send(.priorityChanged(fileIndices: [0], priority: 1)) {
            $0.pendingCommands = []
            $0.activeCommand = .priority(indices: [0], priority: .high)
        }
        await store.receive(.commandResponse(.success(.priority(indices: [0], priority: .high)))) {
            $0.activeCommand = nil
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
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
            $0.errorPresenter.banner = nil
        }
    }

    @Test
    func removeTorrentSuccess() async {
        let torrent = DomainFixtures.torrentDownloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 45)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )

        await store.send(.removeButtonTapped) {
            $0.removeConfirmation = .removeTorrent(name: torrent.name)
        }
        await store.send(.removeConfirmation(.presented(.deleteTorrentOnly))) {
            $0.removeConfirmation = nil
            $0.pendingCommands = []
            $0.activeCommand = .remove(deleteData: false)
        }
        await store.receive(.commandResponse(.success(.remove(deleteData: false)))) {
            $0.activeCommand = nil
        }
        await store.receive(.delegate(.torrentRemoved(torrent.id)))
    }

    @Test
    func removeTorrentFailure() async throws {
        let torrent = DomainFixtures.torrentDownloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 46)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )
        await repositoryStore.markFailure(.remove)
        let expectedMessage = "InMemoryTorrentRepository operation remove marked as failed."

        await store.send(.removeButtonTapped) {
            $0.removeConfirmation = .removeTorrent(name: torrent.name)
        }
        await store.send(.removeConfirmation(.presented(.deleteTorrentOnly))) {
            $0.removeConfirmation = nil
            $0.pendingCommands = []
            $0.activeCommand = .remove(deleteData: false)
        }
        await store.receive(
            .commandResponse(
                .failure(.remove(deleteData: false), expectedMessage)
            )
        ) {
            $0.activeCommand = nil
        }
        await store.receive(.commandFailed(expectedMessage)) {
            $0.alert = .error(message: expectedMessage)
        }
    }

    @Test
    func priorityUpdateFailureShowsAlert() async throws {
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 5)
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 47)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )
        await repositoryStore.markFailure(.updateFileSelection)
        let expectedMessage =
            "InMemoryTorrentRepository operation updateFileSelection marked as failed."

        await store.send(.priorityChanged(fileIndices: [0], priority: 1)) {
            $0.pendingCommands = []
            $0.activeCommand = .priority(indices: [0], priority: .high)
        }
        await store.receive(
            .commandResponse(
                .failure(.priority(indices: [0], priority: .high), expectedMessage)
            )
        ) {
            $0.activeCommand = nil
        }
        await store.receive(.commandFailed(expectedMessage)) {
            $0.alert = .error(message: expectedMessage)
        }
    }

    @Test
    // swiftlint:disable:next function_body_length
    func commandsQueueSequentially() async throws {
        let clock = TestClock()
        var torrent = DomainFixtures.torrentDownloading
        torrent.id = .init(rawValue: 20)
        torrent.status = .stopped
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [torrent])
        let repository = TorrentRepository.test(
            fetchDetails: { identifier in
                try await repositoryStore.withTorrents(.fetchDetails) { torrents in
                    guard let torrent = torrents.first(where: { $0.id == identifier }) else {
                        throw InMemoryTorrentRepositoryError.torrentNotFound(identifier)
                    }
                    return torrent
                }
            },
            start: { ids in
                try await clock.sleep(for: .seconds(1))
                try await repositoryStore.withTorrents(.start) { torrents in
                    for index in torrents.indices where ids.contains(torrents[index].id) {
                        torrents[index].status = .downloading
                    }
                }
            },
            stop: { ids in
                try await clock.sleep(for: .seconds(1))
                try await repositoryStore.withTorrents(.stop) { torrents in
                    for index in torrents.indices where ids.contains(torrents[index].id) {
                        torrents[index].status = .stopped
                    }
                }
            },
            remove: { _, _ in throw TorrentRepositoryTestError.unimplemented },
            verify: { _ in throw TorrentRepositoryTestError.unimplemented },
            updateTransferSettings: { _, _ in throw TorrentRepositoryTestError.unimplemented },
            updateFileSelection: { _, _ in throw TorrentRepositoryTestError.unimplemented }
        )
        let timestamp = Date(timeIntervalSince1970: 60)
        let store = makeDetailStore(
            torrent: torrent,
            repository: repository,
            timestamp: timestamp
        )

        await store.send(.startTapped) {
            $0.pendingCommands = []
            $0.activeCommand = .start
        }
        await store.send(.pauseTapped) {
            $0.pendingCommands = [.pause]
        }

        await clock.advance(by: .seconds(1))
        await store.receive(.commandResponse(.success(.start))) {
            $0.activeCommand = .pause
            $0.pendingCommands = []
        }
        await store.receive(.commandDidFinish(L10n.tr("torrentDetail.status.started"))) {
            $0.alert = .info(message: L10n.tr("torrentDetail.status.started"))
            $0.activeCommand = .pause
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
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

        await clock.advance(by: .seconds(1))
        await store.receive(.commandResponse(.success(.pause))) {
            $0.activeCommand = nil
        }
        await store.receive(.commandDidFinish(L10n.tr("torrentDetail.status.stopped"))) {
            $0.alert = .info(message: L10n.tr("torrentDetail.status.stopped"))
        }
        await store.receive(.refreshRequested) {
            $0.isLoading = true
            $0.errorPresenter.banner = nil
        }
        expected.status = .stopped
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
                ),
                SpeedSample(
                    timestamp: timestamp,
                    downloadRate: expected.summary.transfer.downloadRate,
                    uploadRate: expected.summary.transfer.uploadRate
                )
            ]
        }
    }

    @Test("detailsResponse отправляет delegate при pendingListSync")
    func detailsResponseEmitsDelegateWhenSyncPending() async {
        let baseTorrent = DomainFixtures.torrentDownloading
        var updatedTorrent = baseTorrent
        updatedTorrent.status = .seeding
        updatedTorrent.summary.progress.percentDone = 0.9

        var initialState = TorrentDetailReducer.State(torrent: baseTorrent)
        initialState.pendingListSync = true

        let store = TestStoreFactory.make(
            initialState: initialState,
            reducer: { TorrentDetailReducer() },
            configure: { dependencies in
                dependencies = AppDependencies.makeTestDefaults()
            }
        )

        let response = TorrentDetailReducer.DetailsResponse(
            torrent: updatedTorrent,
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        await store.send(.detailsResponse(.success(response))) {
            $0.isLoading = false
            $0.errorPresenter.banner = nil
            $0.apply(response.torrent)
            $0.speedHistory.samples = [
                SpeedSample(
                    timestamp: response.timestamp,
                    downloadRate: response.torrent.summary.transfer.downloadRate,
                    uploadRate: response.torrent.summary.transfer.uploadRate
                )
            ]
            $0.pendingListSync = false
        }

        await store.receive(.delegate(.torrentUpdated(updatedTorrent)))
    }
}

// swiftlint:enable file_length
