import SwiftUI

/// Типы действий над торрентом.
enum TorrentActionType: String, CaseIterable, Sendable {
    case start
    case pause
    case verify
    case remove

    var title: String {
        switch self {
        case .start: return L10n.tr("torrentDetail.actions.start")
        case .pause: return L10n.tr("torrentDetail.actions.pause")
        case .verify: return L10n.tr("torrentDetail.actions.verify")
        case .remove: return L10n.tr("torrentDetail.actions.remove")
        }
    }

    var systemImage: String {
        switch self {
        case .start: return "play.fill"
        case .pause: return "pause.fill"
        case .verify: return "checkmark.shield.fill"
        case .remove: return "trash.fill"
        }
    }

    var tint: Color {
        switch self {
        case .start: return .green
        case .pause: return .orange
        case .verify: return .blue
        case .remove: return .red
        }
    }

    var accessibilityIdentifier: String {
        "torrent-action-\(self.rawValue)"
    }
}
