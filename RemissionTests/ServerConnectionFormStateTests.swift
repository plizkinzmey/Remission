import Foundation
import Testing

@testable import Remission

@Suite("Server Connection Form State Tests")
struct ServerConnectionFormStateTests {
    // Проверяет нормализацию хоста и пути, включая тримминг и ведущий слеш.
    @Test
    func normalizationTrimsHostAndNormalizesPath() {
        var state = ServerConnectionFormState()
        state.host = "  example.com  "
        state.path = " rpc "

        #expect(state.trimmedHost == "example.com")
        #expect(state.normalizedHost == "example.com")
        #expect(state.normalizedPath == "/rpc")
    }

    // Проверяет fallback пути по умолчанию, если путь пустой или из пробелов.
    @Test
    func normalizedPathFallsBackToDefaultWhenEmpty() {
        var state = ServerConnectionFormState()
        state.path = "   "
        #expect(state.normalizedPath == "/transmission/rpc")
    }

    // Проверяет валидацию порта и формы.
    @Test
    func portValidationAndFormValidity() {
        var state = ServerConnectionFormState()
        state.host = "server"

        state.port = "9091"
        #expect(state.portValue == 9091)
        #expect(state.isFormValid)

        state.port = "70000"
        #expect(state.portValue == nil)
        #expect(state.isFormValid == false)
    }

    // Проверяет нормализацию имени: если имя пустое, используется хост.
    @Test
    func normalizedNameFallsBackToHost() {
        var state = ServerConnectionFormState()
        state.name = "   "
        state.host = "example.org"
        #expect(state.normalizedName == "example.org")
    }

    // Проверяет загрузку из HTTPS-конфига и перенос флагов безопасности.
    @Test
    func initFromServerConfigMapsHttpsSecurity() {
        let server = ServerConfig.previewSecureSeedbox
        let state = ServerConnectionFormState(server: server)

        #expect(state.transport == .https)
        #expect(state.allowUntrustedCertificates == false)
        #expect(state.username == "seeduser")
    }

    // Проверяет, что makeServerConfig собирает корректный ServerConfig.
    @Test
    func makeServerConfigBuildsExpectedConfiguration() {
        var state = ServerConnectionFormState()
        state.name = "  My Server  "
        state.host = " host.local "
        state.port = "443"
        state.path = "api"
        state.transport = .https
        state.allowUntrustedCertificates = true
        state.username = "admin"

        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let createdAt = Date(timeIntervalSince1970: 123)
        let config = state.makeServerConfig(id: id, createdAt: createdAt)

        #expect(config.id == id)
        #expect(config.createdAt == createdAt)
        #expect(config.connection.host == "host.local")
        #expect(config.connection.port == 443)
        #expect(config.connection.path == "/api")
        #expect(config.authentication?.username == "admin")
        #expect(config.isSecure)
        #expect(config.usesInsecureTransport == false)
    }
}
