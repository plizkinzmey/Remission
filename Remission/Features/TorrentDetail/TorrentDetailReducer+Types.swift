import Foundation

extension TorrentDetailReducer {
    // MARK: - Supporting Types
    struct DetailsResponse: Equatable {
        var torrent: Torrent
        var timestamp: Date
    }

    enum Delegate: Equatable {
        case closeRequested
        case torrentUpdated(Torrent)
        case torrentRemoved(Torrent.Identifier)
        case removeRequested(Torrent.Identifier, deleteData: Bool)
    }

    enum CommandCategory: Equatable { case start, pause, verify, remove, priority }
    enum CommandKind: Equatable {
        case start, pause, verify
        case remove(deleteData: Bool)
        case priority(indices: [Int], priority: TorrentRepository.FilePriority)
        var category: CommandCategory {
            switch self {
            case .start: return .start
            case .pause: return .pause
            case .verify: return .verify
            case .remove: return .remove
            case .priority: return .priority
            }
        }
    }
}
