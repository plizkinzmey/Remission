import ComposableArchitecture
import Foundation

enum TorrentListItem {}

extension TorrentListItem {
    @ObservableState
    struct State: Equatable, Identifiable, Sendable {
        var torrent: Torrent
        var metrics: Metrics
        var isRemoving: Bool

        var id: Torrent.Identifier { torrent.id }

        init(torrent: Torrent, isRemoving: Bool = false) {
            self.torrent = torrent
            self.metrics = Metrics(torrent: torrent)
            self.isRemoving = isRemoving
        }

        mutating func update(with torrent: Torrent) {
            self.torrent = torrent
            self.metrics = Metrics(torrent: torrent)
        }
    }

    struct Metrics: Equatable, Sendable {
        var progressFraction: Double
        var progressText: String
        var downloadRateText: String
        var uploadRateText: String
        var speedSummary: String
        var etaSeconds: Int
        var etaText: String?

        init(torrent: Torrent) {
            let rawProgress = Self.progressValue(for: torrent)
            let clampedProgress = min(max(rawProgress, 0), 1)
            self.progressFraction = clampedProgress
            self.progressText = TorrentDataFormatter.progress(clampedProgress)
            self.downloadRateText = TorrentDataFormatter.speed(torrent.summary.transfer.downloadRate)
            self.uploadRateText = TorrentDataFormatter.speed(torrent.summary.transfer.uploadRate)
            self.speedSummary = "↓ \(downloadRateText) · ↑ \(uploadRateText)"
            self.etaSeconds = torrent.summary.progress.etaSeconds
            let eta = TorrentDataFormatter.eta(torrent.summary.progress.etaSeconds)
            self.etaText = torrent.summary.progress.etaSeconds > 0 ? "ETA \(eta)" : nil
        }

        private static func progressValue(for torrent: Torrent) -> Double {
            switch torrent.status {
            case .checking, .checkWaiting:
                return torrent.summary.progress.recheckProgress
            default:
                return torrent.summary.progress.percentDone
            }
        }
    }
}
