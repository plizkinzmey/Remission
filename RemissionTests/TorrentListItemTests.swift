import Foundation
import Testing

@testable import Remission

@Suite("Torrent List Item Presentation Tests")
struct TorrentListItemTests {
    @Test("Metrics calculation for downloading status")
    func testMetricsCalculation_Downloading() {
        var torrent = Torrent.previewDownloading
        torrent.status = .downloading
        torrent.summary.progress.percentDone = 0.5

        let item = TorrentListItem.State(torrent: torrent)

        #expect(item.metrics.progressFraction == 0.5)
        #expect(item.metrics.progressText == "50.0%")
    }

    @Test("Metrics calculation for checking status (hash recheck)")
    func testMetricsCalculation_Checking() {
        var torrent = Torrent.previewDownloading
        torrent.status = .checking
        torrent.summary.progress.percentDone = 0.5  // Should be ignored in checking phase
        torrent.summary.progress.recheckProgress = 0.8

        let item = TorrentListItem.State(torrent: torrent)

        #expect(item.metrics.progressFraction == 0.8)
    }

    @Test("ETA text formatting")

    func testMetricsCalculation_ETAText() {

        var torrent = Torrent.previewDownloading

        torrent.summary.progress.etaSeconds = 3661  // 1h 1m 1s

        let item = TorrentListItem.State(torrent: torrent)

        // Just verify it's formatted and doesn't equal placeholder

        #expect(item.metrics.etaText != nil)

        #expect(item.metrics.etaText?.isEmpty == false)

        torrent.summary.progress.etaSeconds = -1

        let itemNoETA = TorrentListItem.State(torrent: torrent)

        #expect(itemNoETA.metrics.etaText == nil)

    }
}
