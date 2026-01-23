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
        TorrentDataFormatter.progress(value)
    }

    static func bytes(_ bytes: Int) -> String {
        TorrentDataFormatter.bytes(Int64(bytes))
    }

    static func speed(_ bytesPerSecond: Int) -> String {
        TorrentDataFormatter.speed(bytesPerSecond)
    }

    static func date(from timestamp: Int) -> String {
        let date: Date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func eta(_ seconds: Int) -> String {
        TorrentDataFormatter.eta(seconds)
    }

    static func priorityText(_ priority: Int) -> String {
        switch priority {
        case -1, 0: return L10n.tr("torrentDetail.priority.low")
        case 2: return L10n.tr("torrentDetail.priority.high")
        default: return L10n.tr("torrentDetail.priority.normal")
        }
    }

    static func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case -1, 0: return .gray
        case 2: return .red
        default: return .blue
        }
    }
}
