import Foundation
import Testing

@testable import Remission

@Suite("Torrent List Fields Tests")
struct TorrentListFieldsTests {
    // Проверяет, что details содержит все summary-поля и дополнительные поля деталей.
    @Test
    func detailsContainSummaryAndDetailFields() {
        let summary = TorrentListFields.summary
        let details = TorrentListFields.details

        for field in summary {
            #expect(details.contains(field))
        }

        #expect(details.contains("downloadDir"))
        #expect(details.contains("files"))
        #expect(details.contains("trackerStats"))
        #expect(details.count > summary.count)
    }

    // Проверяет несколько критичных полей, без которых список будет неполным.
    @Test
    func summaryContainsCriticalFields() {
        let summary = TorrentListFields.summary
        #expect(summary.contains("id"))
        #expect(summary.contains("name"))
        #expect(summary.contains("status"))
        #expect(summary.contains("percentDone"))
        #expect(summary.contains("rateDownload"))
        #expect(summary.contains("rateUpload"))
    }
}
