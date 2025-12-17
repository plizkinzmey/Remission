import Foundation
import Testing

@testable import Remission

struct TorrentDetailFormattersTests {
    @Test
    func statusTextMapping() {
        #expect(
            TorrentDetailFormatters.statusText(for: 0)
                == L10n.tr("torrentDetail.statusText.stopped"))
        #expect(
            TorrentDetailFormatters.statusText(for: 4)
                == L10n.tr("torrentDetail.statusText.downloading"))
        #expect(
            TorrentDetailFormatters.statusText(for: 6)
                == L10n.tr("torrentDetail.statusText.seeding"))
        #expect(
            TorrentDetailFormatters.statusText(for: 999)
                == L10n.tr("torrentDetail.statusText.unknown"))
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
        let expected: String = String(
            format: L10n.tr("torrentDetail.speed.format"),
            formatter.string(fromByteCount: 256_000)
        )
        #expect(TorrentDetailFormatters.speed(256_000) == expected)
        #expect(TorrentDetailFormatters.speed(0) == L10n.tr("torrentDetail.speed.zero"))
    }

    @Test
    func etaFormattingHandlesNegativeAndPositive() {
        #expect(TorrentDetailFormatters.eta(-1) == L10n.tr("torrentDetail.eta.placeholder"))
        #expect(
            TorrentDetailFormatters.eta(59)
                == String(format: L10n.tr("torrentDetail.eta.minutes"), Int64(0))
        )
        #expect(
            TorrentDetailFormatters.eta(3_661)
                == String(
                    format: L10n.tr("torrentDetail.eta.hoursMinutes"),
                    Int64(1),
                    Int64(1)
                )
        )
    }

    @Test
    func priorityTextMapping() {
        #expect(TorrentDetailFormatters.priorityText(0) == L10n.tr("torrentDetail.priority.low"))
        #expect(TorrentDetailFormatters.priorityText(1) == L10n.tr("torrentDetail.priority.normal"))
        #expect(TorrentDetailFormatters.priorityText(2) == L10n.tr("torrentDetail.priority.high"))
    }
}
