import Foundation
import Testing

@testable import Remission

@Suite("Diagnostics Log Formatter Tests")
struct DiagnosticsLogFormatterTests {
    private func makeEntry(
        message: String = "Network is down",
        metadata: [String: String] = [:],
        level: AppLogLevel = .error,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> DiagnosticsLogEntry {
        DiagnosticsLogEntry(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            timestamp: timestamp,
            level: level,
            message: message,
            category: "network",
            metadata: metadata
        )
    }

    // Проверяет очистку metadata: тримминг, удаление пустых и чувствительных ключей.
    @Test
    func sanitizedMetadataRemovesSensitiveAndEmptyValues() {
        let sanitized = DiagnosticsLogFormatter.sanitizedMetadata([
            " host ": " example.com ",
            "authToken": "secret",
            "empty": "   "
        ])

        #expect(sanitized[" host "] == "example.com")
        #expect(sanitized.keys.contains("authToken") == false)
        #expect(sanitized.keys.contains("empty") == false)
    }

    // Проверяет формирование тэгов из metadata, включая retry/maxRetries.
    @Test
    func metadataTagsIncludeHighlightsAndRetryContext() {
        let entry = makeEntry(
            metadata: [
                "method": "torrent-get",
                "status": "409",
                "host": "seedbox.io",
                "path": "/rpc",
                "server": "abcd1234",
                "elapsed_ms": "25",
                "retry_attempt": "2",
                "max_retries": "5"
            ]
        )

        let tags = DiagnosticsLogFormatter.metadataTags(for: entry)
        #expect(tags.contains("torrent-get"))
        #expect(tags.contains("status 409"))
        #expect(tags.contains("seedbox.io"))
        #expect(tags.contains("/rpc"))
        #expect(tags.contains("server abcd1234"))
        #expect(tags.contains("25 ms"))
        #expect(tags.contains("retry #2"))
        #expect(tags.contains("max 5"))
    }

    // Проверяет определение offline-ситуаций и сетевых проблем.
    @Test
    func offlineAndNetworkIssueDetection() {
        let offlineEntry = makeEntry(message: "The network is down")
        #expect(DiagnosticsLogFormatter.isOffline(offlineEntry))
        #expect(DiagnosticsLogFormatter.isNetworkIssue(offlineEntry))

        let statusEntry = makeEntry(metadata: ["status": "500"])
        #expect(DiagnosticsLogFormatter.isNetworkIssue(statusEntry))
    }

    // Проверяет сборку текста для копирования, включая сортировку metadata.
    @Test
    func copyTextContainsSortedMetadata() {
        let entry = makeEntry(
            metadata: [
                "b": "2",
                "a": "1"
            ],
            level: .warning
        )

        let text = DiagnosticsLogFormatter.copyText(for: entry)
        #expect(text.contains("[WARNING]"))
        #expect(text.contains("a=1; b=2"))
    }

    // Проверяет, что copyText(for:) сортирует записи по убыванию времени.
    @Test
    func copyTextForEntriesSortsByTimestampDescending() {
        let oldEntry = makeEntry(message: "old", timestamp: Date(timeIntervalSince1970: 10))
        let newEntry = makeEntry(message: "new", timestamp: Date(timeIntervalSince1970: 20))

        let combined = DiagnosticsLogFormatter.copyText(for: [oldEntry, newEntry])
        let lines = combined.split(separator: "\n").map(String.init)

        #expect(lines.count == 2)
        #expect(lines.first?.contains("new") == true)
        #expect(lines.last?.contains("old") == true)
    }
}
