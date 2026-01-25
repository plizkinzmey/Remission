import Foundation

/// Агрегированные метрики хранилища, рассчитанные по текущему списку торрентов и состоянию сессии.
struct StorageSummary: Equatable, Sendable {
    var totalBytes: Int64
    var freeBytes: Int64
    var updatedAt: Date?

    /// Объём занятого места торрентами. Для безопасности результат ограничен снизу нулём.
    var usedBytes: Int64 {
        max(totalBytes - freeBytes, 0)
    }

    init(totalBytes: Int64, freeBytes: Int64, updatedAt: Date? = nil) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.updatedAt = updatedAt
    }

    /// Строит сводку по хранилищу на основе торрентов и снимка свободного места из сессии.
    /// Возвращает `nil`, если состояние сессии недоступно.
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
