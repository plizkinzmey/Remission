import Foundation

/// Представление дисковых метрик Transmission для UI.
struct StorageSummary: Equatable, Sendable {
    private var storage: SessionState.Storage
    var updatedAt: Date?

    var totalBytes: Int64 { storage.totalBytes }
    var freeBytes: Int64 { storage.freeBytes }
    var usedBytes: Int64 { storage.usedBytes }

    init(storage: SessionState.Storage, updatedAt: Date? = nil) {
        self.storage = storage
        self.updatedAt = updatedAt
    }

    init(totalBytes: Int64, freeBytes: Int64, updatedAt: Date? = nil) {
        self.init(
            storage: .init(totalBytes: totalBytes, freeBytes: freeBytes),
            updatedAt: updatedAt
        )
    }

    static func from(session: SessionState?, updatedAt: Date?) -> StorageSummary? {
        guard let session else { return nil }
        return StorageSummary(storage: session.storage, updatedAt: updatedAt)
    }
}
