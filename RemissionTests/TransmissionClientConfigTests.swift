import Foundation
import Testing

@testable import Remission

@Suite("TransmissionClientConfig")
struct TransmissionClientConfigTests {
    @Test("Инициализация по умолчанию выставляет ожидаемые значения")
    func defaultInitializationSetsExpectedValues() throws {
        // Этот тест фиксирует дефолты, на которые опираются live-зависимости и ретраи.
        let baseURL = try #require(URL(string: "http://localhost:9091/transmission/rpc"))
        let config = TransmissionClientConfig(baseURL: baseURL)

        #expect(config.baseURL == baseURL)
        #expect(config.username == nil)
        #expect(config.password == nil)
        #expect(config.requestTimeout == 30)
        #expect(config.maxRetries == 3)
        #expect(config.retryDelay == 1)
        #expect(config.serverID == nil)
        #expect(config.enableLogging == false)
    }

    @Test("maskedForLogging не раскрывает пароль и корректно отображает username")
    func maskedForLoggingHidesPasswordAndShowsUsernameFallback() throws {
        // Мы специально не проверяем точный формат всей строки,
        // а фиксируем «контракт безопасности»: пароля быть не должно.
        let baseURL = try #require(URL(string: "https://example.com/transmission/rpc"))

        let withUser = TransmissionClientConfig(
            baseURL: baseURL,
            username: "alice",
            password: "super-secret"
        )
        let withoutUser = TransmissionClientConfig(
            baseURL: baseURL,
            username: "",
            password: "super-secret"
        )

        #expect(withUser.maskedForLogging.contains("alice"))
        #expect(!withUser.maskedForLogging.contains("super-secret"))

        // Пустое имя пользователя должно заменяться на <no-username>.
        #expect(withoutUser.maskedForLogging.contains("<no-username>"))
        #expect(!withoutUser.maskedForLogging.contains("super-secret"))
    }
}
