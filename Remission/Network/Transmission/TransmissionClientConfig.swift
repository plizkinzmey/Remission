import Foundation

/// Конфигурация TransmissionClient.
/// Содержит параметры подключения, таймауты и настройки логирования.
public struct TransmissionClientConfig: Sendable {
    /// URL базовый адрес сервера (например, "http://localhost:9091/transmission/rpc").
    public var baseURL: URL

    /// Имя пользователя для Basic Auth. Нил, если аутентификация не используется.
    public var username: String?

    /// Пароль для Basic Auth. Нил, если аутентификация не используется.
    public var password: String?

    /// Таймаут для запросов (по умолчанию 10 секунд).
    public var requestTimeout: TimeInterval

    /// Количество попыток повтора при временных ошибках (по умолчанию 1).
    public var maxRetries: Int

    /// Интервал между повторами в секундах (по умолчанию 1).
    public var retryDelay: TimeInterval

    /// Идентификатор сервера для контекстного логирования.
    public var serverID: UUID?

    /// Логировать ли запросы/ответы (с маскировкой чувствительных данных).
    public var enableLogging: Bool

    /// Логгер для вывода логов запросов/ответов.
    /// По умолчанию используется NoOpTransmissionLogger (ничего не логирует).
    public var logger: TransmissionLogger

    /// Инициализация конфигурации с основными параметрами.
    /// - Parameters:
    ///   - baseURL: URL сервера (например, "http://localhost:9091/transmission/rpc").
    ///   - username: Имя пользователя или `nil`, если Basic Auth не нужен.
    ///   - password: Пароль или `nil`, если Basic Auth не нужен.
    ///   - requestTimeout: Таймаут запроса в секундах (по умолчанию 30).
    ///   - maxRetries: Максимум повторов (по умолчанию 3).
    ///   - retryDelay: Интервал между повторами в секундах (по умолчанию 1).
    ///   - enableLogging: Включить логирование (по умолчанию false).
    ///   - logger: Логгер для вывода логов (по умолчанию NoOpTransmissionLogger).
    public init(
        baseURL: URL,
        username: String? = nil,
        password: String? = nil,
        requestTimeout: TimeInterval = 10,
        maxRetries: Int = 1,
        retryDelay: TimeInterval = 1,
        serverID: UUID? = nil,
        enableLogging: Bool = false,
        logger: TransmissionLogger = NoOpTransmissionLogger.shared
    ) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.requestTimeout = requestTimeout
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.serverID = serverID
        self.enableLogging = enableLogging
        self.logger = logger
    }

    /// Маскированная версия конфигурации для логирования (без пароля).
    nonisolated var maskedForLogging: String {
        let usernameDescription: String = username?.isEmpty == false ? username! : "<no-username>"
        return
            "TransmissionClientConfig(baseURL: \(baseURL), username: \(usernameDescription), timeout: \(requestTimeout)s)"
    }
}
