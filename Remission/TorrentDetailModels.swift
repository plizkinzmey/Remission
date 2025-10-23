import Foundation

/// Модель файла в торренте
struct TorrentFile: Equatable, Identifiable {
    var id: Int { index }
    var index: Int
    var name: String
    var length: Int
    var bytesCompleted: Int
    var priority: Int

    var progress: Double {
        guard length > 0 else { return 0.0 }
        return Double(bytesCompleted) / Double(length)
    }
}

/// Модель трекера
struct TorrentTracker: Equatable, Identifiable {
    var id: Int { index }
    var index: Int
    var announce: String
    var tier: Int

    var displayName: String {
        URL(string: announce)?.host ?? announce
    }
}

/// Статистика трекера
struct TrackerStat: Equatable, Identifiable {
    var id: Int { trackerId }
    var trackerId: Int
    var lastAnnounceResult: String = ""
    var downloadCount: Int = 0
    var leecherCount: Int = 0
    var seederCount: Int = 0
}

/// История скоростей
struct SpeedSample: Equatable, Identifiable {
    var id: Date { timestamp }
    var timestamp: Date
    var downloadRate: Int
    var uploadRate: Int
}

/// Источник пиров
struct PeerSource: Equatable, Identifiable {
    var id: String { name }
    var name: String
    var count: Int
}
