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

    @Test("Verify stays locked through intermediate status changes until check starts (no flicker)")
    func testVerifyLockDoesNotClearOnIntermediateStatuses() async {
        let torrentID = Torrent.Identifier(rawValue: 1)

        let initialTorrent: Torrent = {
            var torrent = Torrent.previewDownloading
            torrent.id = torrentID
            torrent.status = .downloading
            return torrent
        }()

        var torrentRepo = TorrentRepository.testValue
        torrentRepo.verifyClosure = { @Sendable ids in
            #expect(ids == [torrentID])
        }
        torrentRepo.fetchDetailsClosure = { @Sendable _ in initialTorrent }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: .sample,
            torrentRepository: torrentRepo
        )

        let store = TestStore(
            initialState: {
                var state = TorrentDetailReducer.State(
                    torrentID: torrentID,
                    connectionEnvironment: environment
                )
                state.apply(initialTorrent)
                return state
            }()
        ) {
            TorrentDetailReducer()
        }

        store.exhaustivity = .off

        // Tap verify: should lock immediately and keep a pending status change.
        await store.send(.verifyTapped) {
            $0.activeCommand = .verify
            $0.pendingStatusChange = .init(command: .verify, initialStatus: $0.status)
        }

        await store.receive(\.commandResponse) {
            $0.activeCommand = nil
            $0.pendingListSync = true
        }

        // Details arrive with an intermediate (non-checking) status: should remain locked.
        var intermediate = initialTorrent
        intermediate.status = .downloadWaiting
        await store.send(
            .detailsResponse(
                .success(.init(torrent: intermediate, timestamp: Date()))
            )
        ) {
            #expect($0.pendingStatusChange != nil)
            #expect($0.isVerifyLocked == true)
        }

        // Then it goes back to downloading: still locked (we haven't started checking yet).
        var back = initialTorrent
        back.status = .downloading
        await store.send(
            .detailsResponse(
                .success(.init(torrent: back, timestamp: Date()))
            )
        ) {
            #expect($0.pendingStatusChange != nil)
            #expect($0.isVerifyLocked == true)
        }

        // Once check starts, the pending status change is cleared, but lock remains via status.
        var checking = initialTorrent
        checking.status = .checkWaiting
        await store.send(
            .detailsResponse(
                .success(.init(torrent: checking, timestamp: Date()))
            )
        ) {
            #expect($0.pendingStatusChange == nil)
            #expect($0.isVerifyLocked == true)
        }
    }
}
