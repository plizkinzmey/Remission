import Foundation
import Testing

@testable import Remission

// Тесты версионирования Transmission RPC
//
// Проверяет совместимость с версиями Transmission 3.0+ (RPC v14+).
// Минимальная поддерживаемая версия: Transmission 3.0 (RPC v14)
// Рекомендуемая версия: Transmission 4.0+ (RPC v17+)
//
// **Справочные материалы:**
// - Transmission RPC версионирование: devdoc/TRANSMISSION_RPC_REFERENCE.md
// - Swift Testing: https://developer.apple.com/documentation/testing
//
// swiftlint:disable explicit_type_interface static_over_final_class
// Тесты для проверки версии Transmission через реальную реализацию TransmissionClient.
// Используем URLProtocol мок для подмены сетевого транспорта.
@Suite("TransmissionClient Version Check Tests")
@MainActor
struct TransmissionClientVersionCheckTests {

    /// Тестирует успешную проверку совместимой версии (RPC v17 = Transmission 4.0+).
    @Test("checkServerVersion успешно проверяет совместимую версию RPC v17")
    func testVersionCheckCompatible() async throws {
        // Arrange: создаём реальный клиент с mock URLSession
        let mockSession: URLSession = createMockSession(
            responseJSON: """
                {
                    "result": "success",
                    "arguments": {
                        "rpc-version": 17,
                        "rpc-version-minimum": 14,
                        "version": "4.0.0"
                    }
                }
                """
        )

        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: URL(string: "http://localhost:9091/transmission/rpc")!,
            enableLogging: false
        )
        let client: TransmissionClient = TransmissionClient(config: config, session: mockSession)

        // Act
        let (compatible, rpcVersion) = try await client.checkServerVersion()

        // Assert
        #expect(compatible == true)
        #expect(rpcVersion == 17)
    }

    /// Тестирует выброс versionUnsupported при старой версии (RPC v13 = Transmission 2.x).
    @Test("checkServerVersion выбрасывает versionUnsupported для RPC v13")
    func testVersionCheckIncompatible() async throws {
        // Arrange: старая версия (Transmission 2.x)
        let mockSession: URLSession = createMockSession(
            responseJSON: """
                {
                    "result": "success",
                    "arguments": {
                        "rpc-version": 13,
                        "version": "2.94"
                    }
                }
                """
        )

        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: URL(string: "http://localhost:9091/transmission/rpc")!,
            enableLogging: false
        )
        let client: TransmissionClient = TransmissionClient(config: config, session: mockSession)

        // Act & Assert
        do {
            _ = try await client.checkServerVersion()
            #expect(Bool(false), "Expected versionUnsupported error")
        } catch let error as APIError {
            if case .versionUnsupported(let version) = error {
                #expect(version.contains("13") || version.contains("2.94"))
            } else {
                #expect(Bool(false), "Expected versionUnsupported, got \(error)")
            }
        }
    }

    /// Тестирует граничный случай минимальной версии (RPC v14 = Transmission 3.0).
    @Test("checkServerVersion успешно проверяет минимальную версию RPC v14")
    func testVersionCheckMinimumVersion() async throws {
        // Arrange: ровно минимальная версия RPC v14
        let mockSession: URLSession = createMockSession(
            responseJSON: """
                {
                    "result": "success",
                    "arguments": {
                        "rpc-version": 14
                    }
                }
                """
        )

        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: URL(string: "http://localhost:9091/transmission/rpc")!,
            enableLogging: false
        )
        let client: TransmissionClient = TransmissionClient(config: config, session: mockSession)

        // Act
        let (compatible, rpcVersion) = try await client.checkServerVersion()

        // Assert
        #expect(compatible == true)
        #expect(rpcVersion == 14)
    }

    /// Тестирует обработку отсутствующего поля rpc-version в ответе.
    @Test("checkServerVersion выбрасывает decodingFailed при отсутствии rpc-version")
    func testVersionCheckMissingField() async throws {
        // Arrange: ответ без rpc-version
        let mockSession: URLSession = createMockSession(
            responseJSON: """
                {
                    "result": "success",
                    "arguments": {
                        "version": "4.0.0"
                    }
                }
                """
        )

        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: URL(string: "http://localhost:9091/transmission/rpc")!,
            enableLogging: false
        )
        let client: TransmissionClient = TransmissionClient(config: config, session: mockSession)

        // Act & Assert
        do {
            _ = try await client.checkServerVersion()
            #expect(Bool(false), "Expected decodingFailed error")
        } catch let error as APIError {
            if case .decodingFailed(let details) = error {
                #expect(details.contains("rpc-version"))
            } else {
                #expect(Bool(false), "Expected decodingFailed, got \(error)")
            }
        }
    }

    /// Тестирует обработку некорректного типа rpc-version (строка вместо числа).
    @Test("checkServerVersion выбрасывает decodingFailed при некорректном типе rpc-version")
    func testVersionCheckInvalidType() async throws {
        // Arrange: rpc-version как строка вместо числа
        let mockSession: URLSession = createMockSession(
            responseJSON: """
                {
                    "result": "success",
                    "arguments": {
                        "rpc-version": "17"
                    }
                }
                """
        )

        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: URL(string: "http://localhost:9091/transmission/rpc")!,
            enableLogging: false
        )
        let client: TransmissionClient = TransmissionClient(config: config, session: mockSession)

        // Act & Assert
        do {
            _ = try await client.checkServerVersion()
            #expect(Bool(false), "Expected decodingFailed error")
        } catch let error as APIError {
            if case .decodingFailed = error {
                // Успех - ожидаемая ошибка
            } else {
                #expect(Bool(false), "Expected decodingFailed, got \(error)")
            }
        }
    }
}

// MARK: - URLProtocol Mock для подмены сетевого транспорта

/// Создаёт URLSession с mock URLProtocol для возврата заданного JSON-ответа.
private func createMockSession(responseJSON: String) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]

    // Сохраняем mock-ответ в статическую переменную для доступа из URLProtocol
    MockURLProtocol.mockResponseJSON = responseJSON

    return URLSession(configuration: config)
}

/// Mock URLProtocol для эмуляции HTTP-ответов без реальных сетевых запросов.
private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var mockResponseJSON: String = ""

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseData = Self.mockResponseJSON.data(using: .utf8) else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: nil)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Ничего не делаем
    }
}

// swiftlint:enable explicit_type_interface static_over_final_class
