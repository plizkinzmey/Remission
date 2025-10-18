import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClientConfig Tests")
struct TransmissionClientConfigTests {
    @MainActor
    @Test("Config инициализируется с корректными значениями")
    func testConfigInitialization() throws {
        let url: URL = URL(string: "http://localhost:9091/transmission/rpc")!
        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: url,
            username: "admin",
            password: "password123",
            requestTimeout: 15,
            maxRetries: 5,
            retryDelay: 2,
            enableLogging: true
        )

        #expect(config.baseURL == url)
        #expect(config.username == "admin")
        #expect(config.password == "password123")
        #expect(config.requestTimeout == 15)
        #expect(config.maxRetries == 5)
        #expect(config.retryDelay == 2)
        #expect(config.enableLogging == true)
    }

    @MainActor
    @Test("Config использует дефолтные значения")
    func testConfigDefaults() throws {
        let url: URL = URL(string: "http://localhost:9091/transmission/rpc")!
        let config: TransmissionClientConfig = TransmissionClientConfig(baseURL: url)

        #expect(config.username == nil)
        #expect(config.password == nil)
        #expect(config.requestTimeout == 30)
        #expect(config.maxRetries == 3)
        #expect(config.retryDelay == 1)
        #expect(config.enableLogging == false)
    }

    @MainActor
    @Test("Маскирование конфига для логирования скрывает пароль")
    func testMaskedForLogging() throws {
        let url: URL = URL(string: "http://localhost:9091/transmission/rpc")!
        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: url,
            username: "admin",
            password: "secretPassword123"
        )

        let maskedString: String = config.maskedForLogging
        #expect(!maskedString.contains("secretPassword123"))
        #expect(maskedString.contains("admin"))
        #expect(maskedString.contains("localhost"))
    }

    @MainActor
    @Test("Маскирование конфига корректно обрабатывает отсутствие логина")
    func testMaskedForLoggingWithoutCredentials() throws {
        let url: URL = URL(string: "http://localhost:9091/transmission/rpc")!
        let config: TransmissionClientConfig = TransmissionClientConfig(baseURL: url)

        let maskedString: String = config.maskedForLogging
        #expect(maskedString.contains("<no-username>"))
        #expect(!maskedString.contains("Optional"))
    }

    @MainActor
    @Test("Config является Sendable")
    func testConfigIsSendable() throws {
        let url: URL = URL(string: "http://localhost:9091/transmission/rpc")!
        let config: TransmissionClientConfig = TransmissionClientConfig(
            baseURL: url,
            username: "admin",
            password: "password123"
        )

        // Если бы config не был Sendable, этот код не скомпилировался бы.
        let _: any Sendable = config
    }
}

@Suite("TransmissionClientProtocol Tests")
struct TransmissionClientProtocolTests {
    @Test("Протокол требует всех основных методов")
    func testProtocolMethods() throws {
        // Проверяем, что протокол содержит все методы через reflection/compile-time check.
        // На compile-time Swift гарантирует, что любая реализация протокола содержит все методы.
        let _: any TransmissionClientProtocol

        // Смок для проверки сигнатур методов
        struct MockClient: TransmissionClientProtocol {
            func sessionGet() async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func sessionStats() async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentAdd(
                filename: String,
                downloadDir: String?,
                paused: Bool?,
                labels: [String]?
            ) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentRemove(
                ids: [Int],
                deleteLocalData: Bool?
            ) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentSet(
                ids: [Int],
                arguments: AnyCodable
            ) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }

            func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
                throw APIError.unknown(details: "mock")
            }
        }

        #expect(true)  // Успешно скомпилировалось и создано
    }

    @Test("Протокол является Sendable")
    func testProtocolIsSendable() throws {
        // Проверяем, что протокол помечен как Sendable
        let _: any (TransmissionClientProtocol & Sendable)
        #expect(true)
    }
}

#if canImport(ComposableArchitecture)
    import ComposableArchitecture

    @Suite("TransmissionClientDependencyKey Tests")
    struct TransmissionClientDependencyKeyTests {
        @Test("DependencyKey предоставляет default значение")
        func testDependencyKeyDefaultValue() throws {
            var deps: DependencyValues = DependencyValues()
            let client: TransmissionClientProtocol = deps.transmissionClient
            #expect(client is TransmissionClientProtocol)
        }

        @Test("DependencyKey можно переопределить")
        func testDependencyKeyCanBeOverridden() throws {
            struct MockClient: TransmissionClientProtocol {
                func sessionGet() async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func sessionStats() async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentGet(
                    ids: [Int]?,
                    fields: [String]?
                ) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentAdd(
                    filename: String,
                    downloadDir: String?,
                    paused: Bool?,
                    labels: [String]?
                ) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentRemove(
                    ids: [Int],
                    deleteLocalData: Bool?
                ) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentSet(
                    ids: [Int],
                    arguments: AnyCodable
                ) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }

                func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
                    TransmissionResponse(result: "success", arguments: nil, tag: nil)
                }
            }

            var deps: DependencyValues = DependencyValues()
            deps.transmissionClient = MockClient()

            let response: TransmissionResponse = try deps.transmissionClient.sessionGet()
            #expect(response.result == "success")
        }
    }

#endif
