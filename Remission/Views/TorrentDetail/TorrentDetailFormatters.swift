import Foundation
import SwiftUI

enum TorrentDetailFormatters {
    static func statusText(for status: Int) -> String {
        switch status {
        case 0: return L10n.tr("torrentDetail.statusText.stopped")
        case 1: return L10n.tr("torrentDetail.statusText.queueCheck")
        case 2: return L10n.tr("torrentDetail.statusText.checking")
        case 3: return L10n.tr("torrentDetail.statusText.downloadQueue")
        case 4: return L10n.tr("torrentDetail.statusText.downloading")
        case 5: return L10n.tr("torrentDetail.statusText.seedQueue")
        case 6: return L10n.tr("torrentDetail.statusText.seeding")
        default: return L10n.tr("torrentDetail.statusText.unknown")
        }
    }

    static func progress(_ value: Double) -> String {
        let clamped = max(0, min(value, 1))
        return String(format: "%.1f%%", clamped * 100)
    }

    static func bytes(_ bytes: Int) -> String {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func speed(_ bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else { return L10n.tr("torrentDetail.speed.zero") }
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/с"
    }

    static func date(from timestamp: Int) -> String {
        let date: Date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func eta(_ seconds: Int) -> String {
        if seconds < 0 { return L10n.tr("torrentDetail.eta.placeholder") }
        let hours: Int = seconds / 3600
        let minutes: Int = (seconds % 3600) / 60
        if hours > 0 {
            return String(
                format: L10n.tr("torrentDetail.eta.hoursMinutes"),
                Int64(hours),
                Int64(minutes)
            )
        } else {
            return String(
                format: L10n.tr("torrentDetail.eta.minutes"),
                Int64(minutes)
            )
        }
    }

    static func priorityText(_ priority: Int) -> String {
        switch priority {
        case 0: return L10n.tr("torrentDetail.priority.low")
        case 2: return L10n.tr("torrentDetail.priority.high")
        default: return L10n.tr("torrentDetail.priority.normal")
        }
    }

    static func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 0: return .gray
        case 2: return .red
        default: return .blue
        }
    }
}
