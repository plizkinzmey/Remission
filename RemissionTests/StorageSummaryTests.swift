import Foundation
import Testing

@testable import Remission

@Suite("Storage Summary Tests")
struct StorageSummaryTests {
    // Этот тест фиксирует контракт: без состояния сессии мы не можем
    // корректно посчитать свободное место, поэтому ожидаем `nil`.
    @Test("Calculate returns nil when session is missing")
    func calculateReturnsNilWithoutSession() {
        let torrents = [Torrent.sampleDownloading()]

        let summary = StorageSummary.calculate(
            torrents: torrents,
            session: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(summary == nil)
    }

    // Этот тест проверяет «нулевой» сценарий: торрентов нет.
    // В этом случае:
    // - занятое место равно 0,
    // - общее место должно совпадать со свободным,
    // - дата обновления пробрасывается как есть.
    @Test("Empty torrent list produces zero used bytes")
    func emptyTorrentList() {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_123)
        var session = SessionState.previewActive
        session.storage.freeBytes = 500

        let summary = StorageSummary.calculate(
            torrents: [],
            session: session,
            updatedAt: updatedAt
        )

        #expect(summary != nil)
        #expect(summary?.freeBytes == 500)
        #expect(summary?.totalBytes == 500)
        #expect(summary?.usedBytes == 0)
        #expect(summary?.updatedAt == updatedAt)
    }

    // Этот тест покрывает основной расчёт:
    // - занятое место — это сумма totalSize по всем торрентам,
    // - общее место — это used + free.
    // Мы задаём маленькие контролируемые размеры, чтобы тест был
    // максимально прозрачным и устойчивым к изменениям фикстур.
    @Test("Used bytes are summed from torrent totalSize")
    func sumsTorrentSizes() {
        var first = Torrent.sampleDownloading()
        first.summary.progress.totalSize = 100
        var second = Torrent.sampleSeeding()
        second.summary.progress.totalSize = 250

        var session = SessionState.previewActive
        session.storage.freeBytes = 1_000

        let summary = StorageSummary.calculate(
            torrents: [first, second],
            session: session,
            updatedAt: nil
        )

        #expect(summary != nil)
        #expect(summary?.usedBytes == 350)
        #expect(summary?.freeBytes == 1_000)
        #expect(summary?.totalBytes == 1_350)
    }

    // Этот тест проверяет защиту от отрицательных значений в usedBytes.
    // Даже если по какой-то причине freeBytes окажется больше totalBytes,
    // `usedBytes` должен быть ограничен снизу нулём.
    @Test("Used bytes are clamped to zero")
    func usedBytesIsClampedToZero() {
        let summary = StorageSummary(totalBytes: 100, freeBytes: 150, updatedAt: nil)

        #expect(summary.usedBytes == 0)
    }
}
