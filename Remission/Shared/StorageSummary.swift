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
}
