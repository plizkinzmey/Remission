import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Torrent Detail Feature Tests")
@MainActor
struct TorrentDetailFeatureTests {

    @Test("Initial load success")
    func testTask_InitialLoad_Success() async {
        let torrentID = Torrent.Identifier(rawValue: 1)
        let torrent = Torrent.previewDownloading
        let now = Date()

        var torrentRepo = TorrentRepository.placeholder
        torrentRepo.fetchDetailsClosure = { @Sendable _ in torrent }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .sample,
            torrentRepository: torrentRepo
        )

        let store = TestStore(
            initialState: TorrentDetailReducer.State(
                torrentID: torrentID, connectionEnvironment: environment)
        ) {
            TorrentDetailReducer()
        } withDependencies: {
            $0.dateProvider.now = { @Sendable in now }
        }

        store.exhaustivity = .off

        await store.send(TorrentDetailReducer.Action.task)

        await store.receive(\.detailsResponse.success) {
            $0.isLoading = false
            $0.apply(torrent)
        }
    }

    @Test("Start command execution")
    func testStartTapped() async {
        let torrentID = Torrent.Identifier(rawValue: 1)
        var torrentRepo = TorrentRepository.placeholder
        torrentRepo.startClosure = { @Sendable _ in }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .sample,
            torrentRepository: torrentRepo
        )

        let store = TestStore(
            initialState: TorrentDetailReducer.State(
                torrentID: torrentID, connectionEnvironment: environment)
        ) {
            TorrentDetailReducer()
        }

        store.exhaustivity = .off

        await store.send(TorrentDetailReducer.Action.startTapped) {
            $0.activeCommand = .start
            $0.pendingStatusChange = .init(command: .start, initialStatus: $0.status)
        }

        await store.receive(\.commandResponse) {
            $0.activeCommand = nil
            $0.pendingListSync = true
        }

        await store.receive(
            TorrentDetailReducer.Action.commandDidFinish(L10n.tr("torrentDetail.status.started")))

        await store.receive(TorrentDetailReducer.Action.refreshRequested)
    }
}
