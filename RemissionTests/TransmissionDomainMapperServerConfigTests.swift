import Foundation
import Testing

@testable import Remission

@Suite("TransmissionDomainMapper ServerConfig")
struct TransmissionDomainMapperServerConfigTests {
    @Test("mapServerConfig заполняет path по умолчанию и создаёт authentication без credentials")
    func mapServerConfigBuildsServerConfigWithDefaults() throws {
        // Этот тест фиксирует важное поведение: path может быть nil в storage,
        // но доменная модель всегда должна иметь корректный путь.
        let mapper = TransmissionDomainMapper()
        let before = Date()

        let record = StoredServerConfigRecord(
            id: UUID(),
            name: "Home NAS",
            host: "nas.local",
            port: 9091,
            path: nil,
            isSecure: false,
            username: "alice",
            createdAt: nil
        )

        let server = try mapper.mapServerConfig(record: record, credentials: nil)
        let after = Date()

        #expect(server.connection.path == "/transmission/rpc")
        #expect(server.authentication?.username == "alice")
        #expect(server.security == .http)

        // createdAt должен быть выставлен даже при отсутствии значения в storage.
        #expect(server.createdAt >= before)
        #expect(server.createdAt <= after)
    }

    @Test("mapServerConfig валидирует обязательные поля и порт")
    func mapServerConfigValidatesRequiredFields() {
        // Мы явно проверяем error-path'ы, чтобы не потерять понятные ошибки при рефакторинге.
        let mapper = TransmissionDomainMapper()
        let id = UUID()

        let emptyName = StoredServerConfigRecord(
            id: id,
            name: "",
            host: "host",
            port: 9091,
            path: nil,
            isSecure: false,
            username: nil,
            createdAt: Date()
        )
        #expect(
            throws: DomainMappingError.missingField(field: "name", context: "server-config")
        ) {
            try mapper.mapServerConfig(record: emptyName, credentials: nil)
        }

        let invalidPort = StoredServerConfigRecord(
            id: id,
            name: "Server",
            host: "host",
            port: 0,
            path: nil,
            isSecure: false,
            username: nil,
            createdAt: Date()
        )
        #expect(
            throws: DomainMappingError.invalidValue(
                field: "port",
                description: "значение должно быть > 0",
                context: "server-config"
            )
        ) {
            try mapper.mapServerConfig(record: invalidPort, credentials: nil)
        }
    }

    @Test("makeAuthentication возвращает nil без username и валидирует credentials key")
    func makeAuthenticationHandlesOptionalUsernameAndCredentialMismatch() throws {
        // Здесь мы покрываем безопасность: credentials должны совпадать с record,
        // иначе получаем явную ошибку, а не молчаливое рассогласование.
        let mapper = TransmissionDomainMapper()

        let noAuthRecord = StoredServerConfigRecord(
            id: UUID(),
            name: "No Auth",
            host: "example.com",
            port: 443,
            path: nil,
            isSecure: true,
            username: nil,
            createdAt: Date()
        )
        #expect(try mapper.makeAuthentication(for: noAuthRecord, credentials: nil) == nil)

        let record = StoredServerConfigRecord(
            id: UUID(),
            name: "Secure",
            host: "example.com",
            port: 443,
            path: nil,
            isSecure: true,
            username: "alice",
            createdAt: Date()
        )

        let matchingCredentials = TransmissionServerCredentials(
            key: TransmissionServerCredentialsKey(
                host: "example.com",
                port: 443,
                isSecure: true,
                username: "alice"
            ),
            password: "secret"
        )
        let authentication = try mapper.makeAuthentication(
            for: record, credentials: matchingCredentials)
        #expect(authentication?.username == "alice")

        let mismatchedCredentials = TransmissionServerCredentials(
            key: TransmissionServerCredentialsKey(
                host: "example.com",
                port: 443,
                isSecure: true,
                username: "bob"
            ),
            password: "secret"
        )
        #expect(
            throws: DomainMappingError.invalidValue(
                field: "credentials",
                description: "ключ не соответствует сохранённым настройкам сервера",
                context: "server-config"
            )
        ) {
            try mapper.makeAuthentication(for: record, credentials: mismatchedCredentials)
        }
    }
}
