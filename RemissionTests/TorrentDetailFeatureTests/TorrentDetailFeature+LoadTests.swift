import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct TorrentDetailFeatureLoadTests {
    @Test
    func loadTorrentDetailsSuccess() async throws {
        let response = TorrentDetailTestHelpers.makeParserResponse()
        let expectedSnapshot = TorrentDetailTestHelpers.makeParserSnapshot()
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
            state.name = expectedSnapshot.name ?? ""
            state.status = expectedSnapshot.status ?? 0
            state.percentDone = expectedSnapshot.percentDone ?? 0
            state.totalSize = expectedSnapshot.totalSize ?? 0
            state.downloadedEver = expectedSnapshot.downloadedEver ?? 0
            state.uploadedEver = expectedSnapshot.uploadedEver ?? 0
            state.eta = expectedSnapshot.eta ?? 0
            state.rateDownload = expectedSnapshot.rateDownload ?? 0
            state.rateUpload = expectedSnapshot.rateUpload ?? 0
            state.uploadRatio = expectedSnapshot.uploadRatio ?? 0
            state.downloadLimit = expectedSnapshot.downloadLimit ?? 0
            state.downloadLimited = expectedSnapshot.downloadLimited ?? false
            state.uploadLimit = expectedSnapshot.uploadLimit ?? 0
            state.uploadLimited = expectedSnapshot.uploadLimited ?? false
            state.peersConnected = expectedSnapshot.peersConnected ?? 0
            state.peersFrom = expectedSnapshot.peersFrom
            state.downloadDir = expectedSnapshot.downloadDir ?? ""
            state.dateAdded = expectedSnapshot.dateAdded ?? 0
            state.files = expectedSnapshot.files
            state.trackers = expectedSnapshot.trackers
            state.trackerStats = expectedSnapshot.trackerStats
            state.speedHistory = [
                SpeedSample(
                    timestamp: timestamp, downloadRate: state.rateDownload,
                    uploadRate: state.rateUpload)
            ]
        }
    }
}
