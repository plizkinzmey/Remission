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

    // Проверяет строгую валидацию и фильтрацию кириллицы/пробелов для каждого поля.
    @Test
    func inputFilteringAndCyrillicRestrictions() {
        var state = ServerConnectionFormState()

        // 1. Имя сервера: разрешает кириллицу и пробелы
        state.name = "Мой Сервер 123!@#"
        #expect(state.name == "Мой Сервер 123")

        // 2. Хост: блокирует кириллицу и пробелы, разрешает ASCII и IPv6
        state.host = "хост.ru"
        #expect(state.host == ".ru")  // "хост" отсекается, так как это кириллица

        state.host = "my host.local"
        #expect(state.host == "myhost.local")  // Пробел отсекается

        state.host = "[2001:db8::1]"
        #expect(state.host == "[2001:db8::1]")  // IPv6 разрешен

        // 3. Порт: только цифры, макс длина 5
        state.port = "90a912"
        #expect(state.port == "90912")  // 'a' отсекается

        state.port = "123456"
        #expect(state.port == "12345")  // Ограничение в 5 символов

        // 4. Путь: блокирует кириллицу и пробелы, разрешает ASCII спецсимволы
        state.path = "/путь/rpc"
        #expect(state.path == "//rpc")  // Кириллица отсекается

        state.path = "/transmission /rpc"
        #expect(state.path == "/transmission/rpc")  // Пробел отсекается

        // 5. Пользователь: блокирует кириллицу и пробелы
        state.username = "юзер name"
        #expect(state.username == "name")

        // 6. Пароль: блокирует кириллицу, разрешает пробелы и ASCII спецсимволы
        state.password = "пароль P@$$w0rd 123"
        #expect(state.password == " P@$$w0rd 123")
    }
}
