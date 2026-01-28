import Foundation
import Testing

@testable import Remission

@Suite("Session State Tests")
struct SessionStateTests {
    // Проверяет, что при нулевом downloadedBytes ratio считается бесконечным.
    @Test
    func lifetimeRatioIsInfinityWhenDownloadedIsZero() {
        let stats = SessionState.LifetimeStats(
            filesAdded: 0,
            downloadedBytes: 0,
            uploadedBytes: 10,
            sessionCount: 1,
            secondsActive: 1
        )
        #expect(stats.ratio.isInfinite)
    }

    // Проверяет корректный расчет ratio при положительных значениях.
    @Test
    func lifetimeRatioIsUploadedDividedByDownloaded() {
        let stats = SessionState.LifetimeStats(
            filesAdded: 0,
            downloadedBytes: 200,
            uploadedBytes: 50,
            sessionCount: 1,
            secondsActive: 1
        )
        #expect(stats.ratio == 0.25)
    }
}
