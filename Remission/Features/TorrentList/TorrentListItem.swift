import ComposableArchitecture
import Foundation

enum TorrentListItem {}

extension TorrentListItem {
    @ObservableState
    struct State: Equatable, Identifiable, Sendable {
        var torrent: Torrent
        var metrics: Metrics

        var id: Torrent.Identifier { torrent.id }

        init(torrent: Torrent) {
            self.torrent = torrent
            self.metrics = Metrics(torrent: torrent)
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
            let clampedProgress = min(max(torrent.summary.progress.percentDone, 0), 1)
            self.progressFraction = clampedProgress
            self.progressText = String(format: "%.1f%%", clampedProgress * 100)
            self.downloadRateText = Metrics.format(
                bytesPerSecond: torrent.summary.transfer.downloadRate)
            self.uploadRateText = Metrics.format(
                bytesPerSecond: torrent.summary.transfer.uploadRate)
            self.speedSummary = "↓ \(downloadRateText)/с · ↑ \(uploadRateText)/с"
            self.etaSeconds = torrent.summary.progress.etaSeconds
            self.etaText = Metrics.formatETA(seconds: torrent.summary.progress.etaSeconds)
        }

        private static func format(bytesPerSecond: Int) -> String {
            guard bytesPerSecond > 0 else {
                return "0 Б"
            }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .binary
            formatter.allowedUnits = .useAll
            formatter.includesUnit = true
            return formatter.string(fromByteCount: Int64(bytesPerSecond))
        }

        private static func formatETA(seconds: Int) -> String? {
            guard seconds > 0 else { return nil }
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
            formatter.unitsStyle = .abbreviated
            formatter.maximumUnitCount = 2
            if let formatted = formatter.string(from: TimeInterval(seconds)) {
                return "ETA \(formatted)"
            }
            return nil
        }
    }
}
