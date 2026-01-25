import Foundation
import Testing

@testable import Remission

@Suite("Diagnostics Log Entry Tests")
struct DiagnosticsLogEntryTests {
    private func makeEntry(
        level: AppLogLevel = .info,
        message: String = "Network offline",
        category: String = "network",
        metadata: [String: String] = [:]
    ) -> DiagnosticsLogEntry {
        DiagnosticsLogEntry(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            timestamp: Date(timeIntervalSince1970: 123),
            level: level,
            message: message,
            category: category,
            metadata: metadata
        )
    }

    // Проверяет фильтрацию по уровню.
    @Test
    func filterMatchesLevel() {
        let entry = makeEntry(level: .error)
        var filter = DiagnosticsLogFilter()
        filter.level = .error

        #expect(filter.matches(entry))

        filter.level = .warning
        #expect(filter.matches(entry) == false)
    }

    // Проверяет поиск по сообщению, категории и metadata без учета регистра.
    @Test
    func filterSearchMatchesMessageCategoryAndMetadata() {
        let entry = makeEntry(
            message: "Request timed out",
            category: "Transmission",
            metadata: ["host": "seedbox.example.com"]
        )

        var filter = DiagnosticsLogFilter(searchText: "timed OUT")
        #expect(filter.matches(entry))

        filter.searchText = "transmission"
        #expect(filter.matches(entry))

        filter.searchText = "example.com"
        #expect(filter.matches(entry))
    }

    // Проверяет, что пустой или пробельный запрос не фильтрует записи.
    @Test
    func emptySearchTextDoesNotFilterOutEntries() {
        let entry = makeEntry()
        let filter = DiagnosticsLogFilter(level: nil, searchText: "   ")
        #expect(filter.matches(entry))
    }
}
