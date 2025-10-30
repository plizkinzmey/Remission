import Foundation
import Testing

@testable import Remission

// swiftlint:disable explicit_type_interface

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
    // swiftlint:disable function_body_length
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
                filename: String?,
                metainfo: Data?,
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

            func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
                throw APIError.unknown(details: "mock")
            }

            func performHandshake() async throws -> TransmissionHandshakeResult {
                throw APIError.unknown(details: "mock")
            }

            func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {}
        }

        #expect(Bool(true))
    }
    // swiftlint:enable function_body_length

    @Test("Протокол является Sendable")
    func testProtocolIsSendable() throws {
        let _: any (TransmissionClientProtocol & Sendable)
    }
}

#if canImport(ComposableArchitecture)
    import ComposableArchitecture

    @Suite("TransmissionClientDependencyKey Tests")
    struct TransmissionClientDependencyKeyTests {
        private struct SuccessStubTransmissionClient: TransmissionClientProtocol {
            func sessionGet() async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func sessionStats() async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentAdd(
                filename: String?,
                metainfo: Data?,
                downloadDir: String?,
                paused: Bool?,
                labels: [String]?
            ) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentRemove(
                ids: [Int],
                deleteLocalData: Bool?
            ) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentSet(
                ids: [Int],
                arguments: AnyCodable
            ) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "success") }
            }

            func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
                await MainActor.run { (compatible: true, rpcVersion: 17) }
            }

            func performHandshake() async throws -> TransmissionHandshakeResult {
                await MainActor.run {
                    TransmissionHandshakeResult(
                        sessionID: "session-success",
                        rpcVersion: 17,
                        minimumSupportedRpcVersion: 14,
                        serverVersionDescription: "4.0.0",
                        isCompatible: true
                    )
                }
            }

            func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {}
        }

        @MainActor
        @Test("DependencyKey предоставляет default значение")
        func testDependencyKeyDefaultValue() async {
            let deps: DependencyValues = DependencyValues()

            do {
                _ = try await deps.transmissionClient.sessionGet()
                Issue.record("Expected default transmission client to be unconfigured")
            } catch TransmissionClientDependencyError.notConfigured(let name) {
                #expect(name == "sessionGet")
            } catch {
                Issue.record("Unexpected error: \(String(reflecting: error))")
            }
        }

        @MainActor
        @Test("DependencyKey можно переопределить")
        func testDependencyKeyCanBeOverridden() async throws {
            var deps: DependencyValues = DependencyValues()
            deps.transmissionClient = TransmissionClientDependency.live(
                client: SuccessStubTransmissionClient()
            )

            let response = try await deps.transmissionClient.sessionGet()
            #expect(response.result == "success")
        }
    }

    @Suite("TransmissionClientBootstrap Tests")
    struct TransmissionClientBootstrapTests {
        private struct TestTransmissionClient: TransmissionClientProtocol {
            func sessionGet() async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func sessionStats() async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func torrentAdd(
                filename: String?,
                metainfo: Data?,
                downloadDir: String?,
                paused: Bool?,
                labels: [String]?
            ) async throws -> TransmissionResponse {
                await MainActor.run {
                    TransmissionResponse(result: "test-success")
                }
            }

            func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func torrentRemove(
                ids: [Int],
                deleteLocalData: Bool?
            ) async throws -> TransmissionResponse {
                await MainActor.run {
                    TransmissionResponse(result: "test-success")
                }
            }

            func torrentSet(
                ids: [Int],
                arguments: AnyCodable
            ) async throws -> TransmissionResponse {
                await MainActor.run {
                    TransmissionResponse(result: "test-success")
                }
            }

            func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
                await MainActor.run { TransmissionResponse(result: "test-success") }
            }

            func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
                await MainActor.run { (compatible: true, rpcVersion: 17) }
            }

            func performHandshake() async throws -> TransmissionHandshakeResult {
                await MainActor.run {
                    TransmissionHandshakeResult(
                        sessionID: "test-session",
                        rpcVersion: 17,
                        minimumSupportedRpcVersion: 14,
                        serverVersionDescription: "4.0.0",
                        isCompatible: true
                    )
                }
            }

            func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {}
        }

        @MainActor
        @Test("TransmissionClientBootstrap создает корректный live dependency")
        func testBootstrapCreatesLiveDependency() async throws {
            let testClient = TestTransmissionClient()
            let liveDependency = TransmissionClientDependency.live(client: testClient)

            // Проверяем что live dependency работает
            let response = try await liveDependency.sessionGet()
            #expect(response.result == "test-success")

            let version = try await liveDependency.checkServerVersion()
            #expect(version.compatible == true)
            #expect(version.rpcVersion == 17)

            let handshake = try await liveDependency.performHandshake()
            #expect(handshake.sessionID == "test-session")
            #expect(handshake.isCompatible == true)
        }

        @MainActor
        @Test("TransmissionClientBootstrap fallback на placeholder при недоступной конфигурации")
        func testBootstrapFallbackToPlaceholder() async {
            // Симулируем недоступную конфигурацию возвращая nil
            // В реальном коде это произойдет при невалидном URL или других проблемах
            let placeholderDependency = TransmissionClientDependency.placeholder

            await expectNotConfigured(method: "sessionGet") {
                _ = try await placeholderDependency.sessionGet()
            }

            for (methodName, testCall) in placeholderFailureScenarios(
                dependency: placeholderDependency
            ) {
                await expectNotConfigured(method: methodName, execute: testCall)
            }
        }

        @MainActor
        @Test("Динамическое переключение с placeholder на live")
        func testDynamicSwitchPlaceholderToLive() async throws {
            var deps: DependencyValues = DependencyValues()

            // Начинаем с placeholder (проверяем что он действительно не настроен)
            do {
                _ = try await deps.transmissionClient.sessionGet()
                Issue.record("Expected default dependency to be unconfigured")
            } catch TransmissionClientDependencyError.notConfigured {
                // Ожидаемое поведение для default dependency
            } catch {
                Issue.record("Unexpected error from default dependency")
            }

            // Переключаемся на live dependency
            let testClient = TestTransmissionClient()
            deps.transmissionClient = TransmissionClientDependency.live(client: testClient)

            // Проверяем что live dependency работает
            let response = try await deps.transmissionClient.sessionGet()
            #expect(response.result == "test-success")

            // Проверяем что можем вернуться к placeholder
            deps.transmissionClient = TransmissionClientDependency.placeholder

            do {
                _ = try await deps.transmissionClient.sessionGet()
                Issue.record("Expected placeholder to be unconfigured after switch back")
            } catch TransmissionClientDependencyError.notConfigured {
                // Ожидаемое поведение
            } catch {
                Issue.record("Unexpected error after switch back to placeholder")
            }
        }
    }

#endif

// swiftlint:enable explicit_type_interface

private func placeholderFailureScenarios(
    dependency: TransmissionClientDependency
) -> [(String, () async throws -> Void)] {
    [
        (
            "sessionSet",
            { _ = try await dependency.sessionSet(AnyCodable.object([:])) }
        ),
        ("sessionStats", { _ = try await dependency.sessionStats() }),
        ("torrentGet", { _ = try await dependency.torrentGet(nil, nil) }),
        (
            "torrentAdd",
            { _ = try await dependency.torrentAdd(nil, nil, nil, nil, nil) }
        ),
        ("torrentStart", { _ = try await dependency.torrentStart([]) }),
        ("torrentStop", { _ = try await dependency.torrentStop([]) }),
        ("torrentRemove", { _ = try await dependency.torrentRemove([], nil) }),
        (
            "torrentSet",
            { _ = try await dependency.torrentSet([], AnyCodable.object([:])) }
        ),
        ("torrentVerify", { _ = try await dependency.torrentVerify([]) }),
        ("checkServerVersion", { _ = try await dependency.checkServerVersion() }),
        ("performHandshake", { _ = try await dependency.performHandshake() })
    ]
}

@MainActor
private func expectNotConfigured(
    method: String,
    execute: () async throws -> Void
) async {
    do {
        try await execute()
        Issue.record("Expected \(method) to throw notConfigured error")
    } catch TransmissionClientDependencyError.notConfigured(let name) {
        #expect(name == method)
    } catch {
        Issue.record("Unexpected error from \(method): \(String(reflecting: error))")
    }
}
