import Foundation
import Testing

@testable import Remission

@Suite("Transmission Log Context Tests")
struct TransmissionLogContextTests {
    // Проверяет, что merging переопределяет только заданные поля.
    @Test
    func mergingOverridesOnlyProvidedFields() {
        let base = TransmissionLogContext(
            serverID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
            host: "base.host",
            path: "/rpc",
            method: "torrent-get",
            statusCode: 200,
            durationMs: 10,
            retryAttempt: 1,
            maxRetries: 3
        )
        let override = TransmissionLogContext(host: "override.host", statusCode: 409)

        let merged = base.merging(override)
        #expect(merged.host == "override.host")
        #expect(merged.statusCode == 409)
        #expect(merged.path == base.path)
        #expect(merged.method == base.method)
        #expect(merged.maxRetries == base.maxRetries)
    }

    // Проверяет форматирование metadata, включая округление durationMs и masked server id.
    @Test
    func metadataIncludesRoundedDurationAndMaskedServer() {
        let id = UUID(uuidString: "12345678-AAAA-BBBB-CCCC-1234567890AB")!
        let context = TransmissionLogContext(
            serverID: id,
            host: "example.com",
            durationMs: 12.7
        )

        let metadata = context.metadata()
        #expect(metadata["host"] == "example.com")
        #expect(metadata["elapsed_ms"] == "13")
        #expect(metadata["server"] == "12345678")
    }
}
