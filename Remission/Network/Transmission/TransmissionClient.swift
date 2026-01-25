import Foundation
import Security

// swiftlint:disable type_body_length

actor SessionStore {
    private var sessionID: String?

    func load() -> String? {
        sessionID
    }

    func store(_ newValue: String?) {
        sessionID = newValue
    }
}

/// Конкретная реализация TransmissionClientProtocol.
/// Использует URLSession для отправки HTTP запросов к Transmission RPC API.
/// Обрабатывает аутентификацию (Basic Auth + HTTP 409 session-id handshake),
/// парсирование ответов и ошибки согласно Transmission RPC специфике (не JSON-RPC 2.0).
public final class TransmissionClient: TransmissionClientProtocol, Sendable {
    /// Минимально поддерживаемая версия RPC (Transmission 3.0 соответствует 14).
    let minimumRpcVersion: Int = 14

    /// Конфигурация клиента (базовый URL, credentials, таймауты).
    let config: TransmissionClientConfig

    /// Потокобезопасное хранилище session-id.
    let sessionStore: SessionStore = SessionStore()

    /// URLSession для выполнения HTTP запросов.
    private let session: URLSession

    /// Обработчик доверия к TLS сертификатам.
    private let trustEvaluator: TransmissionTrustEvaluator

    /// Делегат URLSession, пробрасывающий TLS события в trust evaluator.
    private let sessionDelegate: TransmissionSessionDelegate

    /// Clock для инъекции время-зависимой логики (retry с задержками).
    /// Позволяет использовать TestClock in тестах для детерминированного управления временем.
    private let clock: any Clock<Duration>

    /// Логгер приложения для контекстного логирования ошибок.
    private let appLogger: AppLogger

    /// Базовый контекст для логирования RPC.
    private let baseLogContext: TransmissionLogContext

    /// Создает "живой" инстанс TransmissionClient с настроенными зависимостями.
    ///
    /// - Parameters:
    ///   - config: Конфигурация клиента.
    ///   - clock: Clock для retry-логики.
    ///   - appLogger: Системный логгер.
    ///   - category: Категория для логгера (например, "transmission" или "probe").
    /// - Returns: Настроенный инстанс TransmissionClient.
    public static func live(
        config: TransmissionClientConfig,
        clock: any Clock<Duration>,
        appLogger: AppLogger,
        category: String
    ) -> TransmissionClient {
        let context = TransmissionLogContext(
            serverID: config.serverID,
            host: config.baseURL.host,
            path: config.baseURL.path
        )

        let logger = DefaultTransmissionLogger(
            appLogger: appLogger.withCategory(category),
            baseContext: context
        )

        // Пересоздаем конфиг с внедренным логгером
        var finalConfig = config
        finalConfig.logger = logger

        return TransmissionClient(
            config: finalConfig,
            clock: clock,
            appLogger: appLogger.withCategory(category),
            baseLogContext: context
        )
    }

    /// Инициализация TransmissionClient с конфигурацией.
    ///
    /// - Parameters:
    ///   - config: Конфигурация (baseURL, credentials, таймауты).
    ///   - sessionConfiguration: Необязательная конфигурация URLSession (для тестов/моков).
    ///   - trustStore: Хранилище отпечатков TLS сертификатов (по умолчанию Keychain).
    ///   - trustDecisionHandler: Колбэк запроса доверия к self-signed сертификатам.
    ///   - clock: Clock для использования в retry логике (по умолчанию `ContinuousClock()`).
    public init(
        config: TransmissionClientConfig,
        sessionConfiguration: URLSessionConfiguration? = nil,
        trustStore: TransmissionTrustStore = TransmissionTrustStore(),
        trustDecisionHandler: TransmissionTrustDecisionHandler? = nil,
        clock: any Clock<Duration>,
        appLogger: AppLogger = .noop,
        baseLogContext: TransmissionLogContext? = nil
    ) {
        self.config = config
        self.clock = clock
        self.appLogger = appLogger
        self.baseLogContext =
            baseLogContext
            ?? TransmissionLogContext(
                serverID: config.serverID,
                host: config.baseURL.host,
                path: config.baseURL.path
            )

        guard let host = config.baseURL.host else {
            preconditionFailure("TransmissionClientConfig.baseURL must contain host component")
        }

        let isSecure: Bool = config.baseURL.scheme?.lowercased() == "https"
        let defaultPort: Int = isSecure ? 443 : 80
        let port: Int = config.baseURL.port ?? defaultPort

        let identity: TransmissionServerTrustIdentity = TransmissionServerTrustIdentity(
            host: host,
            port: port,
            isSecure: isSecure
        )

        let handler: TransmissionTrustDecisionHandler = trustDecisionHandler ?? { _ in .deny }
        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: trustStore,
            decisionHandler: handler
        )
        self.trustEvaluator = evaluator

        let delegate = TransmissionSessionDelegate(trustEvaluator: evaluator)
        self.sessionDelegate = delegate

        let configuration: URLSessionConfiguration = sessionConfiguration ?? .default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(
            configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    /// Обновляет хендлер, который будет вызван при запросе доверия к сертификату.
    public func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {
        Task { await trustEvaluator.updateDecisionHandler(handler) }
    }

    /// Удобный инициализатор для использования конструктора AnyCodable из Dictionary
    func anyCodable(from dictionary: [String: AnyCodable]) -> AnyCodable {
        AnyCodable.object(dictionary)
    }

    // MARK: - RPC Method Enum

    public enum RPCMethod: String {
        case sessionGet = "session-get"
        case sessionSet = "session-set"
        case sessionStats = "session-stats"
        case freeSpace = "free-space"
        case torrentGet = "torrent-get"
        case torrentSet = "torrent-set"
        case torrentAdd = "torrent-add"
        case torrentRemove = "torrent-remove"
        case torrentStart = "torrent-start"
        case torrentStop = "torrent-stop"
        case torrentVerify = "torrent-verify"
    }

    // MARK: - Private Helpers

    /// Отправить RPC запрос к серверу (Type-safe overload).
    func sendRequest(
        method: RPCMethod,
        arguments: AnyCodable? = nil,
        tag: TransmissionTag? = nil
    ) async throws -> TransmissionResponse {
        try await sendRequest(method: method.rawValue, arguments: arguments, tag: tag)
    }

    /// Отправить RPC запрос к серверу.
    /// Обрабатывает HTTP 409 handshake для получения session ID при необходимости.
    ///
    /// - Parameters:
    ///   - method: Имя RPC метода.
    ///   - arguments: Аргументы метода (опционально).
    ///   - tag: Тег запроса для корреляции (опционально).
    ///
    /// - Returns: TransmissionResponse с результатом операции.
    /// - Throws: APIError при сетевых ошибках, парсировании или RPC ошибках.
    func sendRequest(
        method: String,
        arguments: AnyCodable? = nil,
        tag: TransmissionTag? = nil
    ) async throws -> TransmissionResponse {
        let request: TransmissionRequest = TransmissionRequest(
            method: method,
            arguments: arguments,
            tag: tag
        )
        let jsonData: Data = try JSONEncoder().encode(request)

        var urlRequest: URLRequest = URLRequest(url: config.baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = config.requestTimeout

        // Устанавливаем httpBody; httpBodyStream не используем, чтобы избежать опустошения stream в URLProtocol.
        urlRequest.httpBody = jsonData

        await applyAuthenticationHeaders(to: &urlRequest)

        // Логируем запрос если логирование включено
        if config.enableLogging {
            config.logger.logRequest(
                method: method,
                request: urlRequest,
                context: makeLogContext(method: method)
            )
        }

        // Отправляем запрос с retry логикой
        return try await sendRequestWithRetry(urlRequest, method: method, bodyData: jsonData)
    }

    /// Отправить запрос с поддержкой HTTP 409 handshake и повторов.
    ///
    /// - Parameters:
    ///   - urlRequest: URLRequest для отправки.
    ///   - method: Имя RPC метода (для логирования).
    ///
    /// - Returns: TransmissionResponse.
    /// - Throws: APIError при ошибках.
    private func sendRequestWithRetry(
        _ urlRequest: URLRequest,
        method: String,
        bodyData: Data
    ) async throws -> TransmissionResponse {
        var mutableRequest: URLRequest = urlRequest
        var remainingRetries: Int = max(config.maxRetries, 0)
        var retryAttempt = 0
        var handshakeAttempts = 0

        while true {
            // Восстанавливаем тело запроса на каждой попытке, чтобы повторные отправки
            // (после 409 или ретраев) не уходили с пустым телом.
            mutableRequest.httpBody = bodyData

            let attemptStartedAt = Date()
            do {
                let (data, response): (Data, URLResponse) = try await session.data(
                    for: mutableRequest)
                let elapsedMs: Double = Date().timeIntervalSince(attemptStartedAt) * 1_000

                let payload = ResponsePayload(
                    data: data, response: response, method: method, elapsedMs: elapsedMs)
                if let transmissionResponse = try await handleResponse(
                    payload, request: &mutableRequest, handshakeAttempts: &handshakeAttempts
                ) {
                    return transmissionResponse
                }
            } catch let urlError as URLError {
                let shouldRetryError = try await handleURLError(
                    urlError,
                    method: method,
                    remainingRetries: &remainingRetries,
                    retryAttempt: &retryAttempt,
                    elapsedMs: Date().timeIntervalSince(attemptStartedAt) * 1_000
                )
                if remainingRetries > 0 && shouldRetryError {
                    continue
                }
                throw APIError.mapURLError(urlError)
            } catch let apiError as APIError {
                logNetworkError(
                    method: method,
                    error: apiError,
                    retryAttempt: retryAttempt,
                    elapsedMs: Date().timeIntervalSince(attemptStartedAt) * 1_000
                )
                throw apiError
            } catch {
                logNetworkError(
                    method: method,
                    error: error,
                    retryAttempt: retryAttempt,
                    elapsedMs: Date().timeIntervalSince(attemptStartedAt) * 1_000
                )
                throw APIError.unknown(details: error.localizedDescription)
            }
        }
    }

    private struct ResponsePayload: Sendable {
        let data: Data
        let response: URLResponse
        let method: String
        let elapsedMs: Double
    }

    private func handleURLError(
        _ urlError: URLError,
        method: String,
        remainingRetries: inout Int,
        retryAttempt: inout Int,
        elapsedMs: Double
    ) async throws -> Bool {
        logNetworkError(
            method: method,
            error: urlError,
            retryAttempt: retryAttempt,
            elapsedMs: elapsedMs
        )

        if urlError.code == .cancelled {
            if let trustError = await trustEvaluator.consumePendingError() {
                throw mapTrustError(trustError)
            }
        }

        guard shouldRetry(urlError) else {
            return false
        }
        let delay = retryDelay(for: retryAttempt)
        retryAttempt += 1
        try await clock.sleep(for: delay)
        return true
    }

    private func handleResponse(
        _ payload: ResponsePayload,
        request: inout URLRequest,
        handshakeAttempts: inout Int
    ) async throws -> TransmissionResponse? {
        let httpResponse: HTTPURLResponse = try requireHTTPResponse(payload.response)

        // Логируем ответ если логирование включено
        if config.enableLogging {
            config.logger.logResponse(
                method: payload.method,
                statusCode: httpResponse.statusCode,
                responseBody: payload.data,
                context: makeLogContext(
                    method: payload.method,
                    statusCode: httpResponse.statusCode,
                    durationMs: payload.elapsedMs
                )
            )
        }

        if try await processSessionConflictIfNeeded(
            httpResponse,
            request: &request,
            handshakeAttempts: &handshakeAttempts
        ) {
            return nil
        }

        try validateHTTPStatus(httpResponse)
        let transmissionResponse: TransmissionResponse = try decodeTransmissionResponse(
            from: payload.data)

        if transmissionResponse.isError {
            let errorMessage: String = transmissionResponse.errorMessage ?? "Unknown RPC error"
            throw APIError.mapTransmissionError(errorMessage)
        }

        return transmissionResponse
    }

    func makeLogContext(
        method: String,
        statusCode: Int? = nil,
        durationMs: Double? = nil,
        retryAttempt: Int? = nil
    ) -> TransmissionLogContext {
        TransmissionLogContext(
            serverID: baseLogContext.serverID,
            host: baseLogContext.host,
            path: baseLogContext.path,
            method: method,
            statusCode: statusCode,
            durationMs: durationMs,
            retryAttempt: retryAttempt,
            maxRetries: config.maxRetries
        )
    }

    private func logNetworkError(
        method: String,
        error: Error,
        retryAttempt: Int?,
        elapsedMs: Double?
    ) {
        let context = makeLogContext(
            method: method,
            durationMs: elapsedMs,
            retryAttempt: retryAttempt
        )
        config.logger.logError(method: method, error: error, context: context)
    }

    private func requireHTTPResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown(details: "Unsupported URLResponse: \(type(of: response))")
        }
        return httpResponse
    }

    private func processSessionConflictIfNeeded(
        _ httpResponse: HTTPURLResponse,
        request: inout URLRequest,
        handshakeAttempts: inout Int
    ) async throws -> Bool {
        guard httpResponse.statusCode == 409 else {
            return false
        }

        handshakeAttempts += 1
        guard handshakeAttempts <= 2 else {
            throw APIError.sessionConflict
        }

        guard
            let sessionIDFromHeader: String =
                httpResponse
                .value(forHTTPHeaderField: "X-Transmission-Session-Id")
        else {
            throw APIError.sessionConflict
        }

        await sessionStore.store(sessionIDFromHeader)
        request.setValue(sessionIDFromHeader, forHTTPHeaderField: "X-Transmission-Session-Id")
        await applyAuthenticationHeaders(to: &request)
        return true
    }

    private func validateHTTPStatus(_ httpResponse: HTTPURLResponse) throws {
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.mapHTTPStatusCode(httpResponse.statusCode)
        }
    }

    private func decodeTransmissionResponse(from data: Data) throws -> TransmissionResponse {
        guard data.isEmpty == false else {
            throw APIError.decodingFailed(underlyingError: "Empty response body")
        }

        do {
            return try JSONDecoder().decode(TransmissionResponse.self, from: data)
        } catch let decodingError as DecodingError {
            throw APIError.mapDecodingError(decodingError)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.unknown(details: error.localizedDescription)
        }
    }

    private func mapTrustError(_ error: TransmissionTrustError) -> APIError {
        switch error {
        case .userDeclined(let challenge):
            return .tlsTrustDeclined(challenge: challenge)
        case .handlerUnavailable(let challenge):
            return .tlsTrustDeclined(challenge: challenge)
        case .evaluationFailed(let message):
            return .tlsEvaluationFailed(details: message)
        }
    }

    /// Применить заголовки аутентификации (Basic Auth и session-id) к запросу.
    private func applyAuthenticationHeaders(to request: inout URLRequest) async {
        if let authorizationHeader: String = authorizationHeaderValue() {
            request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }

        if let sessionID: String = await sessionStore.load() {
            request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id")
        }
    }

    /// Сформировать значение заголовка Authorization для Basic Auth.
    /// Использует URLCredential с persistence `.forSession` согласно рекомендациям Apple.
    /// Context7: developer.apple.com — «Handling an authentication challenge» (URLCredential).
    private func authorizationHeaderValue() -> String? {
        guard let username = config.username,
            let password = config.password,
            username.isEmpty == false
        else {
            return nil
        }

        let credential: URLCredential = URLCredential(
            user: username,
            password: password,
            persistence: .forSession
        )

        guard let user: String = credential.user,
            let secret: String = credential.password
        else {
            return nil
        }

        let credentialsData: Data = Data("\(user):\(secret)".utf8)
        let base64Credentials: String = credentialsData.base64EncodedString()
        return "Basic \(base64Credentials)"
    }

    /// Определяет, стоит ли повторять запрос для указанной сетевой ошибки.
    private func shouldRetry(_ urlError: URLError) -> Bool {
        switch urlError.code {
        case .notConnectedToInternet,
            .networkConnectionLost,
            .timedOut,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .internationalRoamingOff,
            .callIsActive,
            .dataNotAllowed,
            .secureConnectionFailed,
            .cannotLoadFromNetwork:
            return true
        default:
            return false
        }
    }

    /// Возвращает Duration для указанной попытки ретрая с экспоненциальным ростом.
    private func retryDelay(for attempt: Int) -> Duration {
        guard config.retryDelay > 0 else { return .seconds(0) }
        let exponential = config.retryDelay * pow(2.0, Double(attempt))
        let clamped = min(max(exponential, 0), TimeInterval(Int.max))
        return .milliseconds(Int(clamped * 1_000))
    }
}

// swiftlint:enable type_body_length
