import SwiftUI
import Testing

@testable import Remission

@Suite("Torrent Detail Formatters")
struct TorrentDetailFormattersTests {
    @Test
    func statusTextCoversKnownAndUnknownStatuses() {
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
            TorrentDetailFormatters.statusText(for: 99)
                == L10n.tr("torrentDetail.statusText.unknown"))
    }

    @Test
    func priorityTextAndColorMatchContract() {
        #expect(TorrentDetailFormatters.priorityText(-1) == L10n.tr("torrentDetail.priority.low"))
        #expect(TorrentDetailFormatters.priorityText(0) == L10n.tr("torrentDetail.priority.low"))
        #expect(TorrentDetailFormatters.priorityText(1) == L10n.tr("torrentDetail.priority.normal"))
        #expect(TorrentDetailFormatters.priorityText(2) == L10n.tr("torrentDetail.priority.high"))

        #expect(TorrentDetailFormatters.priorityColor(-1) == .gray)
        #expect(TorrentDetailFormatters.priorityColor(0) == .gray)
        #expect(TorrentDetailFormatters.priorityColor(1) == .blue)
        #expect(TorrentDetailFormatters.priorityColor(2) == .red)
    }
}
