import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct TorrentDetailFeatureLoadTests {
    @Test
    func loadTorrentDetailsSuccess() async throws {
        let response = TorrentDetailTestHelpers.makeParserResponse()
        let expectedTorrent = TorrentDetailTestHelpers.makeParsedTorrent()
        let timestamp = Date(timeIntervalSince1970: 1)

        let store = TestStore(initialState: TorrentDetailReducer.State(torrentId: 1)) {
            TorrentDetailReducer()
        } withDependencies: {
            var client = TransmissionClientDependency.testValue
            client.torrentGet = { _, _ in response }
            $0.transmissionClient = client
            $0.date.now = timestamp
            $0.torrentDetailParser = TorrentDetailTestHelpers.makeParserDependency()
        }

        await store.send(.loadTorrentDetails) {
            $0.isLoading = true
            $0.errorMessage = nil
        }

        await store.receive(.detailsLoaded(response, timestamp)) { state in
            state.isLoading = false
            state.name = expectedTorrent.name
            state.status = expectedTorrent.status.rawValue
            state.percentDone = expectedTorrent.summary.progress.percentDone
            state.totalSize = expectedTorrent.summary.progress.totalSize
            state.downloadedEver = expectedTorrent.summary.progress.downloadedEver
            state.uploadedEver = expectedTorrent.summary.progress.uploadedEver
            state.eta = expectedTorrent.summary.progress.etaSeconds
            state.rateDownload = expectedTorrent.summary.transfer.downloadRate
            state.rateUpload = expectedTorrent.summary.transfer.uploadRate
            state.uploadRatio = expectedTorrent.summary.progress.uploadRatio
            let downloadLimit = expectedTorrent.summary.transfer.downloadLimit
            state.downloadLimit = downloadLimit.kilobytesPerSecond
            state.downloadLimited = downloadLimit.isEnabled
            let uploadLimit = expectedTorrent.summary.transfer.uploadLimit
            state.uploadLimit = uploadLimit.kilobytesPerSecond
            state.uploadLimited = uploadLimit.isEnabled
            state.peersConnected = expectedTorrent.summary.peers.connected
            state.peersFrom = expectedTorrent.summary.peers.sources
            state.downloadDir = expectedTorrent.details?.downloadDirectory ?? ""
            state.dateAdded = Int(
                expectedTorrent.details?.addedDate?.timeIntervalSince1970 ?? 0
            )
            state.files = expectedTorrent.details?.files ?? []
            state.trackers = expectedTorrent.details?.trackers ?? []
            state.trackerStats = expectedTorrent.details?.trackerStats ?? []
            state.speedHistory = [
                SpeedSample(
                    timestamp: timestamp, downloadRate: state.rateDownload,
                    uploadRate: state.rateUpload)
            ]
        }
    }
}
