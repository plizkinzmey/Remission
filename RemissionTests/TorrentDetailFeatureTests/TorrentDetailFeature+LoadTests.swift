import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct TorrentDetailFeatureLoadTests {
    @Test
    func loadTorrentDetailsSuccess() async throws {
        let expectedTorrent = DomainFixtures.torrentDownloading
        let repositoryStore = InMemoryTorrentRepositoryStore(torrents: [expectedTorrent])
        let repository = TorrentRepository.inMemory(store: repositoryStore)
        let timestamp = Date(timeIntervalSince1970: 1)
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .previewLocalHTTP,
            torrentRepository: repository
        )

        let store = TestStoreFactory.make(
            initialState: TorrentDetailReducer.State(
                torrentID: expectedTorrent.id,
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

        await store.receive(
            .detailsResponse(
                .success(.init(torrent: expectedTorrent, timestamp: timestamp))
            )
        ) { state in
            state.isLoading = false
            state.apply(expectedTorrent)
            state.speedHistory.samples = [
                SpeedSample(
                    timestamp: timestamp,
                    downloadRate: expectedTorrent.summary.transfer.downloadRate,
                    uploadRate: expectedTorrent.summary.transfer.uploadRate
                )
            ]
        }
    }
}
