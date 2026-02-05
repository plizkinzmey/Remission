import ComposableArchitecture
import Foundation

enum TorrentListItem {}

extension TorrentListItem {
    @ObservableState
    struct State: Equatable, Identifiable, Sendable {
        struct DisplaySignature: Equatable, Sendable {
            var name: String
            var status: Torrent.Status
            var tags: [String]
            var percentDone: Double
            var recheckProgress: Double
            var downloadRate: Int
            var uploadRate: Int
            var peersConnected: Int
            var uploadRatio: Double
            var etaSeconds: Int
        }

        var torrent: Torrent
        var metrics: Metrics
        var isRemoving: Bool
        var displaySignature: DisplaySignature

        var id: Torrent.Identifier { torrent.id }

        init(torrent: Torrent, isRemoving: Bool = false) {
            self.torrent = torrent
            self.metrics = Metrics(torrent: torrent)
            self.isRemoving = isRemoving
            self.displaySignature = Self.displaySignature(for: torrent)
        }

        @discardableResult
        mutating func update(with torrent: Torrent, updateMetrics: Bool) -> Bool {
            let newSignature = Self.displaySignature(for: torrent)
            if newSignature == displaySignature {
                guard updateMetrics else { return false }
                let newMetrics = Metrics(torrent: torrent)
                if newMetrics != metrics {
                    self.metrics = newMetrics
                    return true
                }
                return false
            }
            self.torrent = torrent
            self.displaySignature = newSignature
            self.metrics = Metrics(torrent: torrent)
            return true
        }

        private static func displaySignature(for torrent: Torrent) -> DisplaySignature {
            DisplaySignature(
                name: torrent.name,
                status: torrent.status,
                tags: torrent.tags,
                percentDone: torrent.summary.progress.percentDone,
                recheckProgress: torrent.summary.progress.recheckProgress,
                downloadRate: torrent.summary.transfer.downloadRate,
                uploadRate: torrent.summary.transfer.uploadRate,
                peersConnected: torrent.summary.peers.connected,
                uploadRatio: torrent.summary.progress.uploadRatio,
                etaSeconds: torrent.summary.progress.etaSeconds
            )
        }
    }

    struct Metrics: Equatable, Sendable {
        var progressFraction: Double
        var progressText: String
        var downloadRateText: String
        var uploadRateText: String
        var speedSummary: String
        var peersText: String
        var ratioText: String
        var ratioTextShort: String
        var etaSeconds: Int
        var etaText: String?

        init(torrent: Torrent) {
            let rawProgress = Self.progressValue(for: torrent)
            let clampedProgress = min(max(rawProgress, 0), 1)
            self.progressFraction = clampedProgress
            self.progressText = TorrentDataFormatter.progress(clampedProgress)
            self.downloadRateText = TorrentDataFormatter.speed(
                torrent.summary.transfer.downloadRate)
            self.uploadRateText = TorrentDataFormatter.speed(torrent.summary.transfer.uploadRate)
            self.speedSummary = "↓ \(downloadRateText) · ↑ \(uploadRateText)"
            self.peersText = String(
                format: L10n.tr("torrentList.peers"),
                Int64(torrent.summary.peers.connected)
            )
            self.ratioText = String(
                format: L10n.tr("torrentList.ratio"),
                locale: Locale.current,
                torrent.summary.progress.uploadRatio
            )
            self.ratioTextShort = String(
                format: L10n.tr("torrentList.ratio.short"),
                locale: Locale.current,
                torrent.summary.progress.uploadRatio
            )
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
