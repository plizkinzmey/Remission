import Foundation
import Testing

@testable import Remission

@Suite("AppLogger")
struct AppLoggerTests {
    @Test("noop-логгер остаётся noop при смене категории")
    func noopRemainsNoopWhenChangingCategory() {
        // Этот тест защищает важный инвариант для тестов и превью:
        // любые производные от .noop не должны внезапно начать логировать «вживую».
        let derived = AppLogger.noop.withCategory("network")
        #expect(derived.isNoop)
    }

    @Test("withDiagnosticsSink отправляет записи в sink без утечки category в metadata")
    func diagnosticsSinkReceivesStructuredEntries() {
        // Логгер добавляет category в metadata для SwiftLog,
        // но для DiagnosticsLogEntry category должен быть отдельным полем.
        let recorder = DiagnosticsRecorder()
        let logger = AppLogger.noop
            .withCategory("rpc")
            .withDiagnosticsSink(recorder.record)

        logger.error("request failed", metadata: ["request_id": "42"])

        let entries = recorder.snapshot()

        #expect(entries.count == 1)
        guard let entry = entries.first else {
            Issue.record("Ожидали хотя бы одну запись в diagnostics sink")
            return
        }

        #expect(entry.level == .error)
        #expect(entry.message == "request failed")
        #expect(entry.category == "rpc")
        #expect(entry.metadata["request_id"] == "42")
        #expect(entry.metadata["category"] == nil)
    }
}

private final class DiagnosticsRecorder: @unchecked Sendable {
    private var entries: [DiagnosticsLogEntry] = []
    private let lock = NSLock()

    func record(_ entry: DiagnosticsLogEntry) {
        lock.lock()
        entries.append(entry)
        lock.unlock()
    }

    func snapshot() -> [DiagnosticsLogEntry] {
        lock.lock()
        let snapshot = entries
        lock.unlock()
        return snapshot
    }
}
