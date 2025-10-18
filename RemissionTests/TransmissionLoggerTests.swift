import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface
@MainActor
@Suite("TransmissionLogger Tests")
struct TransmissionLoggerTests {
    // MARK: - LoggerMasking Tests

    // Thread-safe log collector for capturing logger outputs from a @Sendable closure.
    final class LogStore: @unchecked Sendable {
        private let lock: NSLock = NSLock()
        private var _messages: [String] = []

        func append(_ message: String) {
            lock.lock()
            defer { lock.unlock() }
            _messages.append(message)
        }

        func all() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return _messages
        }
    }

    @Test("DefaultLogger маскирует Authorization header")
    func testDefaultLoggerMasksAuthorizationHeader() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        var request = URLRequest(url: URL(string: "http://localhost:9091/transmission/rpc")!)
        request.setValue("Basic dXNlcjpwYXNzd29yZA==", forHTTPHeaderField: "Authorization")

        logger.logRequest(method: "torrent-get", request: request)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        #expect(logMessage.contains("🔵"))
        #expect(logMessage.contains("torrent-get"))
        // Проверяем, что пароль замаскирован
        #expect(!logMessage.contains("dXNlcjpwYXNzd29yZA=="))
        #expect(logMessage.contains("Basic "))
        #expect(logMessage.contains("..."))
    }

    @Test("DefaultLogger маскирует Session ID")
    func testDefaultLoggerMasksSessionID() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        var request = URLRequest(url: URL(string: "http://localhost:9091/transmission/rpc")!)
        request.setValue("1a2b3c4d5e6f7g8h9i0j", forHTTPHeaderField: "X-Transmission-Session-Id")

        logger.logRequest(method: "session-get", request: request)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        // Проверяем, что session-id замаскирован (первые 4 + ... + последние 4)
        #expect(!logMessage.contains("1a2b3c4d5e6f7g8h9i0j"))
        // Session "1a2b3c4d5e6f7g8h9i0j" -> first 4: "1a2b", last 4: "9i0j" -> "1a2b...9i0j"
        #expect(logMessage.contains("1a2b...9i0j"))
    }

    @Test("DefaultLogger маскирует короткий Session ID")
    func testDefaultLoggerMasksShortSessionID() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        var request = URLRequest(url: URL(string: "http://localhost:9091/transmission/rpc")!)
        request.setValue("12345", forHTTPHeaderField: "X-Transmission-Session-Id")

        logger.logRequest(method: "session-get", request: request)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        // Для коротких session-id должно быть "****"
        #expect(logMessage.contains("****"))
    }

    // MARK: - Response Logging Tests

    @Test("DefaultLogger логирует успешный ответ")
    func testDefaultLoggerLogsSuccessfulResponse() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        let responseData: Data = Data(
            """
            {
              "result": "success",
              "arguments": {"torrents": []},
              "tag": 1
            }
            """.utf8
        )

        logger.logResponse(method: "torrent-get", statusCode: 200, responseBody: responseData)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        #expect(logMessage.contains("✅"))
        #expect(logMessage.contains("torrent-get"))
        #expect(logMessage.contains("200"))
        #expect(logMessage.contains("array(count: 0)"))
        #expect(logMessage.contains("<redacted string>"))
        #expect(!logMessage.contains("success"))
    }

    @Test("DefaultLogger логирует ошибочный ответ")
    func testDefaultLoggerLogsErrorResponse() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        let responseData: Data = Data(
            """
            {
              "result": "session-id-mismatch",
              "tag": 1
            }
            """.utf8
        )

        logger.logResponse(method: "torrent-get", statusCode: 409, responseBody: responseData)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        #expect(logMessage.contains("⚠️"))
        #expect(logMessage.contains("torrent-get"))
        #expect(logMessage.contains("409"))
        #expect(logMessage.contains("<redacted string>"))
        #expect(!logMessage.contains("session-id-mismatch"))
    }

    @Test("DefaultLogger усекает длинные ответы")
    func testDefaultLoggerTruncatesLongResponse() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        // Создаем очень длинный ответ (>500 символов)
        var responseDict: [String: AnyCodable] = [:]
        var torrents: [[String: AnyCodable]] = []
        for index in 0..<100 {
            torrents.append(["id": .int(index), "name": .string("Torrent \(index)")])
        }
        responseDict["torrents"] = .array(torrents.map { .object($0) })

        let responseData = try JSONEncoder().encode(responseDict)
        let originalLength = responseData.count

        logger.logResponse(method: "torrent-get", statusCode: 200, responseBody: responseData)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        #expect(logMessage.contains("array(count: 100)"))
        #expect(!logMessage.contains("Torrent 0"))
        // Лог должен быть значительно короче исходного JSON.
        #expect(logMessage.count < originalLength)
    }

    @Test("DefaultLogger логирует ошибки")
    func testDefaultLoggerLogsErrors() throws {
        let store = LogStore()
        let logger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        let testError = APIError.networkUnavailable
        logger.logError(method: "torrent-get", error: testError)

        let loggedMessages = store.all()
        #expect(loggedMessages.count == 1)
        let logMessage = loggedMessages[0]
        #expect(logMessage.contains("❌"))
        #expect(logMessage.contains("torrent-get"))
    }

    // MARK: - NoOpLogger Tests

    @Test("NoOpLogger ничего не логирует")
    func testNoOpLoggerLogsNothing() throws {
        let logger = NoOpTransmissionLogger.shared

        var request = URLRequest(url: URL(string: "http://localhost:9091/transmission/rpc")!)
        request.setValue("Basic test", forHTTPHeaderField: "Authorization")

        // Эти вызовы не должны вызвать никаких эффектов или ошибок
        logger.logRequest(method: "torrent-get", request: request)
        logger.logResponse(method: "torrent-get", statusCode: 200, responseBody: Data())
        logger.logError(method: "torrent-get", error: APIError.networkUnavailable)

        // Если не было ошибок, тест пройден
        #expect(true)
    }

    // MARK: - Config Integration Tests

    @Test("TransmissionClientConfig инициализируется с дефолтным логгером")
    func testConfigInitializesWithDefaultLogger() throws {
        let url = URL(string: "http://localhost:9091/transmission/rpc")!
        let config = TransmissionClientConfig(baseURL: url)

        #expect(config.enableLogging == false)
        // Дефолтный логгер должен быть NoOpLogger
        let logger = config.logger as? NoOpTransmissionLogger
        #expect(logger != nil)
    }

    @Test("TransmissionClientConfig может быть инициализирована с кастомным логгером")
    func testConfigInitializesWithCustomLogger() throws {
        let url = URL(string: "http://localhost:9091/transmission/rpc")!
        let store = LogStore()
        let customLogger = DefaultTransmissionLogger { message in
            store.append(message)
        }

        let config = TransmissionClientConfig(
            baseURL: url,
            enableLogging: true,
            logger: customLogger
        )

        #expect(config.enableLogging == true)
        // Проверяем, что кастомный логгер работает
        var request = URLRequest(url: url)
        request.setValue("Basic test", forHTTPHeaderField: "Authorization")
        config.logger.logRequest(method: "test", request: request)
        let loggedMessages = store.all()
        #expect(!loggedMessages.isEmpty)
    }
}
// swiftlint:enable explicit_type_interface
