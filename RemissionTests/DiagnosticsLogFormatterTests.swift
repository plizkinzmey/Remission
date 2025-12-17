import Foundation
import Testing

@testable import Remission

@Suite("DiagnosticsLogFormatter")
struct DiagnosticsLogFormatterTests {
    @Test("offline и network issue определяются по ошибке URLError")
    func detectsOfflineErrors() {
        let entry = DiagnosticsLogEntry(
            timestamp: Date(),
            level: .error,
            message: "Network unavailable",
            category: "transmission",
            metadata: [
                "error": "URLError.notConnectedToInternet(-1009)",
                "method": "torrent-get",
                "status": "0"
            ]
        )

        #expect(DiagnosticsLogFormatter.isOffline(entry))
        #expect(DiagnosticsLogFormatter.isNetworkIssue(entry))
    }

    @Test("метаданные очищаются от чувствительных ключей")
    func removesSensitiveMetadata() {
        let metadata = DiagnosticsLogFormatter.sanitizedMetadata([
            "authorization": "Basic abc123",
            "token": "secret-token",
            "host": "nas.local",
            "status": "409"
        ])

        #expect(metadata.keys.contains("authorization") == false)
        #expect(metadata.keys.contains("token") == false)
        #expect(metadata["host"] == "nas.local")
        #expect(metadata["status"] == "409")
    }

    @Test("формат копирования содержит уровень, категорию и метаданные")
    func copyTextFormatsEntry() {
        let entry = DiagnosticsLogEntry(
            timestamp: Date(timeIntervalSince1970: 0),
            level: .warning,
            message: "Retrying request",
            category: "rpc",
            metadata: [
                "method": "POST",
                "status": "503",
                "retry_attempt": "2"
            ]
        )

        let copy = DiagnosticsLogFormatter.copyText(for: entry)
        #expect(copy.contains("WARNING"))
        #expect(copy.contains("rpc"))
        #expect(copy.contains("Retrying request"))
        #expect(copy.contains("retry_attempt=2"))
        #expect(copy.contains("status=503"))
    }
}
