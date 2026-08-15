import Foundation
import Testing

@testable import Remission

@Suite("Storage Summary Tests")
struct StorageSummaryTests {
    @Test("Storage summary returns nil when session is missing")
    func returnsNilWithoutSession() {
        let summary = StorageSummary.from(
            session: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(summary == nil)
    }

    @Test("Storage summary uses Transmission disk metrics")
    func usesTransmissionDiskMetrics() {
        var session = SessionState.previewActive
        session.storage = .init(totalBytes: 2_000, freeBytes: 500)
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_123)

        let summary = StorageSummary.from(session: session, updatedAt: updatedAt)

        #expect(summary?.freeBytes == 500)
        #expect(summary?.totalBytes == 2_000)
        #expect(summary?.usedBytes == 1_500)
        #expect(summary?.updatedAt == updatedAt)
    }

    @Test("Storage metrics clamp used bytes to zero")
    func usedBytesIsClampedToZero() {
        let storage = SessionState.Storage(totalBytes: 100, freeBytes: 150)

        #expect(storage.usedBytes == 0)
    }
}
