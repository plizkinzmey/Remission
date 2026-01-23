import Foundation

/// Конфигурация сохранённого сервера Transmission.
/// Определяет адрес, флаги безопасности и данные для аутентификации.
struct ServerConfig: Equatable, Sendable, Identifiable {
    struct Connection: Equatable, Sendable {
        /// Хост сервера (`host` из настроек пользователя).
        var host: String
        /// Порт RPC (`port`).
        var port: Int
        /// Путь к RPC (`transmission/rpc` по умолчанию).
        var path: String = "/transmission/rpc"
    }

    struct Authentication: Equatable, Sendable {
        /// Имя пользователя для Basic Auth (`username`).
        var username: String
        /// Опциональный идентификатор записи в Keychain.
        /// Значение формируется через `TransmissionServerCredentialsKey`.
        var credentialKey: TransmissionServerCredentialsKey?
    }

    enum Security: Equatable, Sendable {
        /// HTTP без шифрования.
        case http
        /// HTTPS с опциональным разрешением недоверенных сертификатов.
        case https(allowUntrustedCertificates: Bool)
    }

    struct NetworkOptions: Equatable, Sendable {
        static let `default`: NetworkOptions = .init(
            requestTimeout: 30,
            maxRetries: 3,
            retryDelay: 1,
            enableLogging: {
                #if DEBUG
                    return true
                #else
                    return false
                #endif
            }()
        )

        var requestTimeout: TimeInterval
        var maxRetries: Int
        var retryDelay: TimeInterval
        var enableLogging: Bool

    }

    var id: UUID = UUID()
    var name: String
    var connection: Connection
    var security: Security
    var authentication: Authentication?
    /// Дата создания записи – помогает сортировать серверы и строить таймлайны.
    var createdAt: Date = Date()
}

extension ServerConfig {
    /// Возвращает `true`, если соединение использует HTTPS.
    var isSecure: Bool {
        if case .https = security { return true }
        return false
    }

    /// Базовый URL `scheme://host:port/path`.
    var baseURL: URL {
        var components = URLComponents()
        components.scheme = isSecure ? "https" : "http"
        components.host = connection.host
        components.port = connection.port
        components.path = connection.path.hasPrefix("/") ? connection.path : "/\(connection.path)"

        guard let url = components.url else {
            preconditionFailure(
                "Невозможно построить URL для \(connection.host):\(connection.port)"
            )
        }
        return url
    }

    /// Возвращает ключ для доступа к Keychain, если есть имя пользователя.
    var credentialsKey: TransmissionServerCredentialsKey? {
        guard let username = authentication?.username else {
            return nil
        }
        return TransmissionServerCredentialsKey(
            host: connection.host,
            port: connection.port,
            isSecure: isSecure,
            username: username
        )
    }

    /// Строка для отображения адреса в UI.
    var displayAddress: String {
        let scheme: String = isSecure ? "https" : "http"
        return "\(scheme)://\(connection.host):\(connection.port)"
    }

    /// Уникальный fingerprint, используемый для хранения настроек предупреждений HTTP.
    var httpWarningFingerprint: String {
        Self.makeFingerprint(
            host: connection.host,
            port: connection.port,
            username: authentication?.username ?? ""
        )
    }

    /// Возвращает `true`, если сервер использует HTTP.
    var usesInsecureTransport: Bool {
        isSecure == false
    }

    /// Уникальный отпечаток параметров соединения.
    /// Используется для отслеживания изменений, требующих переподключения.
    var connectionFingerprint: String {
        "\(connection.host):\(connection.port):\(connection.path):\(isSecure):\(authentication?.username ?? "")"
    }

    /// Собирает `TransmissionClientConfig`, инкапсулируя знание о сетевых настройках.
    /// - Parameters:
    ///   - password: Пароль из Keychain (если настроен Basic Auth).
    ///   - network: Опции таймаутов/повторов.
    ///   - logger: Логгер для клиента.
    func makeTransmissionClientConfig(
        password: String?,
        network: NetworkOptions = .default,
        logger: TransmissionLogger = NoOpTransmissionLogger.shared
    ) -> TransmissionClientConfig {
        TransmissionClientConfig(
            baseURL: baseURL,
            username: authentication?.username,
            password: password,
            requestTimeout: network.requestTimeout,
            maxRetries: network.maxRetries,
            retryDelay: network.retryDelay,
            serverID: id,
            enableLogging: network.enableLogging,
            logger: logger
        )
    }
}

extension ServerConfig {
    static func makeFingerprint(host: String, port: Int, username: String) -> String {
        "\(host.lowercased()):\(port):\(username.lowercased())"
    }
}

// MARK: - Preview Fixtures

extension ServerConfig {
    /// Фикстура локального NAS с HTTP подключением.
    static let previewLocalHTTP: ServerConfig = .init(
        name: "Домашний NAS",
        connection: .init(host: "nas.local", port: 9091),
        security: .http,
        authentication: .init(username: "admin"),
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    /// Фикстура удалённого Seedbox с HTTPS.
    static let previewSecureSeedbox: ServerConfig = {
        let connection = Connection(
            host: "seedbox.example.com",
            port: 443,
            path: "/transmission/rpc"
        )
        return ServerConfig(
            name: "Seedbox",
            connection: connection,
            security: .https(allowUntrustedCertificates: false),
            authentication: .init(username: "seeduser"),
            createdAt: Date(timeIntervalSince1970: 1_701_111_111)
        )
    }()
}
