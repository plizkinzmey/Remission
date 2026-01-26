import Foundation
import Testing

@testable import Remission

@Suite("TransmissionLogger")
struct TransmissionLoggerTests {
    @Test("logRequest маскирует Authorization и Session-Id в сообщении")
    func logRequestMasksSensitiveHeaders() {
        // Важный инвариант: секреты не должны попадать в лог-сообщения.
        let recorder = DiagnosticsRecorder()
        let logger = DefaultTransmissionLogger(
            appLogger: AppLogger.noop.withDiagnosticsSink(recorder.record)
        )

        var request = URLRequest(url: URL(string: "https://example.com/rpc")!)
        request.setValue("Basic dXNlOnBhc3N3b3Jk", forHTTPHeaderField: "Authorization")
        request.setValue("ABCDEF1234567890", forHTTPHeaderField: "X-Transmission-Session-Id")

        logger.logRequest(method: "session-get", request: request, context: .init())

        guard let entry = recorder.lastEntry() else {
            Issue.record("Ожидали запись лога запроса")
            return
        }

        #expect(entry.message.contains("Authorization: Basic dXNl••••b3Jk"))
        #expect(entry.message.contains("X-Transmission-Session-Id: ABCD••••7890"))
    }

    @Test("logResponse помечает уровень и редактирует JSON")
    func logResponseUsesLevelAndRedactsJSON() {
        // JSON-ответ должен отображаться как структура без реальных значений.
        let recorder = DiagnosticsRecorder()
        let logger = DefaultTransmissionLogger(
            appLogger: AppLogger.noop.withDiagnosticsSink(recorder.record)
        )

        let body: Data
        do {
            body = try JSONSerialization.data(
                withJSONObject: [
                    "name": "secret",
                    "nested": ["token": "abc"],
                    "count": 3
                ]
            )
        } catch {
            Issue.record("Не удалось подготовить JSON-ответ для теста: \(error)")
            return
        }

        logger.logResponse(
            method: "session-get", statusCode: 200, responseBody: body, context: .init())

        guard let entry = recorder.lastEntry() else {
            Issue.record("Ожидали запись лога ответа")
            return
        }

        #expect(entry.level == .info)
        #expect(entry.message.contains("<redacted string>"))
        #expect(entry.message.contains("name"))
        #expect(entry.message.contains("nested"))
        #expect(entry.message.contains("secret") == false)
    }

    @Test("logResponse при 409 использует debug уровень")
    func logResponseUsesDebugFor409() {
        // 409 — часть handshake, не должна считаться ошибкой.
        let recorder = DiagnosticsRecorder()
        let logger = DefaultTransmissionLogger(
            appLogger: AppLogger.noop.withDiagnosticsSink(recorder.record)
        )

        logger.logResponse(
            method: "session-get", statusCode: 409, responseBody: Data(), context: .init())

        guard let entry = recorder.lastEntry() else {
            Issue.record("Ожидали запись лога ответа")
            return
        }

        #expect(entry.level == .debug)
    }

    @Test("logError для cancelled пишет debug")
    func logErrorUsesDebugForCancellation() {
        // Отмена запроса — штатная ситуация и не должна логироваться как error.
        let recorder = DiagnosticsRecorder()
        let logger = DefaultTransmissionLogger(
            appLogger: AppLogger.noop.withDiagnosticsSink(recorder.record)
        )

        logger.logError(method: "torrent-get", error: URLError(.cancelled), context: .init())

        guard let entry = recorder.lastEntry() else {
            Issue.record("Ожидали запись лога ошибки")
            return
        }

        #expect(entry.level == .debug)
        #expect(entry.message.contains("cancelled"))
    }

    @Test("logError для неотменённой ошибки пишет error")
    func logErrorUsesErrorForFailure() {
        // Реальные ошибки должны логироваться уровнем error.
        enum TestError: Error { case failed }

        let recorder = DiagnosticsRecorder()
        let logger = DefaultTransmissionLogger(
            appLogger: AppLogger.noop.withDiagnosticsSink(recorder.record)
        )

        logger.logError(method: "torrent-get", error: TestError.failed, context: .init())

        guard let entry = recorder.lastEntry() else {
            Issue.record("Ожидали запись лога ошибки")
            return
        }

        #expect(entry.level == .error)
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

    func lastEntry() -> DiagnosticsLogEntry? {
        lock.lock()
        let entry = entries.last
        lock.unlock()
        return entry
    }
}
