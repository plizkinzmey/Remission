import Foundation

struct StorageSummary: Equatable, Sendable {
    var totalBytes: Int64
    var freeBytes: Int64
    var updatedAt: Date?

    var usedBytes: Int64 {
        max(totalBytes - freeBytes, 0)
    }

    init(totalBytes: Int64, freeBytes: Int64, updatedAt: Date? = nil) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.updatedAt = updatedAt
    }

    /// Рассчитывает сводку по хранилищу на основе списка торрентов и состояния сессии.
    static func calculate(
        torrents: [Torrent],
        session: SessionState?,
        updatedAt: Date?
    ) -> StorageSummary? {
        guard let session else { return nil }
        let usedBytes = torrents.reduce(Int64(0)) { total, torrent in
            total + Int64(torrent.summary.progress.totalSize)
        }
        let totalBytes = usedBytes + session.storage.freeBytes
        return StorageSummary(
            totalBytes: totalBytes,
            freeBytes: session.storage.freeBytes,
            updatedAt: updatedAt
        )
    }
}
