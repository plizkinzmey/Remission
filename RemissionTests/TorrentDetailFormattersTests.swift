import Foundation
import Testing

@testable import Remission

struct TorrentDetailFormattersTests {
    @Test
    func statusTextMapping() {
        #expect(TorrentDetailFormatters.statusText(for: 0) == "Остановлен")
        #expect(TorrentDetailFormatters.statusText(for: 4) == "Загрузка")
        #expect(TorrentDetailFormatters.statusText(for: 6) == "Раздача")
        #expect(TorrentDetailFormatters.statusText(for: 999) == "Неизвестно")
    }

    @Test
    func progressFormatting() {
        #expect(TorrentDetailFormatters.progress(0.456) == "45.6%")
        #expect(TorrentDetailFormatters.progress(1.0) == "100.0%")
    }

    @Test
    func bytesFormattingMatchesByteCountFormatter() {
        let values: [Int] = [0, 1_024, 1_536_000]
        for value in values {
            let expected: String = {
                let formatter: ByteCountFormatter = ByteCountFormatter()
                formatter.countStyle = .binary
                return formatter.string(fromByteCount: Int64(value))
            }()
            #expect(TorrentDetailFormatters.bytes(value) == expected)
        }
    }

    @Test
    func speedFormattingAppendsSuffix() {
        let formatter: ByteCountFormatter = ByteCountFormatter()
        formatter.countStyle = .binary
        let expected: String = formatter.string(fromByteCount: 256_000) + "/с"
        #expect(TorrentDetailFormatters.speed(256_000) == expected)
        #expect(TorrentDetailFormatters.speed(0) == "0 КБ/с")
    }

    @Test
    func etaFormattingHandlesNegativeAndPositive() {
        #expect(TorrentDetailFormatters.eta(-1) == "—")
        #expect(TorrentDetailFormatters.eta(59) == "0 мин")
        #expect(TorrentDetailFormatters.eta(3_661) == "1 ч 1 мин")
    }

    @Test
    func priorityTextMapping() {
        #expect(TorrentDetailFormatters.priorityText(0) == "Низкий")
        #expect(TorrentDetailFormatters.priorityText(1) == "Нормальный")
        #expect(TorrentDetailFormatters.priorityText(2) == "Высокий")
    }
}
