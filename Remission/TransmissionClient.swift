import Foundation
import Security

// swiftlint:disable type_body_length

private actor SessionStore {
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
    private let minimumRpcVersion: Int = 14

    /// Конфигурация клиента (базовый URL, credentials, таймауты).
    private let config: TransmissionClientConfig

    /// Потокобезопасное хранилище session-id.
    private let sessionStore: SessionStore = SessionStore()

    /// URLSession для выполнения HTTP запросов.
    private let session: URLSession

    /// Обработчик доверия к TLS сертификатам.
    private let trustEvaluator: TransmissionTrustEvaluator

    /// Делегат URLSession, пробрасывающий TLS события в trust evaluator.
    private let sessionDelegate: TransmissionSessionDelegate

    /// Clock для инъекции время-зависимой логики (retry с задержками).
    /// Позволяет использовать TestClock в тестах для детерминированного управления временем.
    private let clock: any Clock<Duration>

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
        clock: any Clock<Duration>
    ) {
        self.config = config
        self.clock = clock

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
        self.session = URLSession(
            configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    /// Обновляет хендлер, который будет вызван при запросе доверия к сертификату.
    public func setTrustDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {
        Task { await trustEvaluator.updateDecisionHandler(handler) }
    }

    /// Удобный инициализатор для использования конструктора AnyCodable из Dictionary
    private func anyCodable(from dictionary: [String: AnyCodable]) -> AnyCodable {
        AnyCodable.object(dictionary)
    }

    // MARK: - Private Helpers

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
    private func sendRequest(
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
        urlRequest.httpBody = jsonData
        await applyAuthenticationHeaders(to: &urlRequest)

        // Логируем запрос если логирование включено
        if config.enableLogging {
            config.logger.logRequest(method: method, request: urlRequest)
        }

        // Отправляем запрос с retry логикой
        return try await sendRequestWithRetry(urlRequest, method: method)
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
        method: String
    ) async throws -> TransmissionResponse {
        var mutableRequest: URLRequest = urlRequest
        var remainingRetries: Int = max(config.maxRetries, 0)
        var retryAttempt: Int = 0
        var handshakeAttempts: Int = 0

        while true {
            do {
                let (data, response): (Data, URLResponse) = try await session.data(
                    for: mutableRequest)

                if let transmissionResponse = try await handleResponse(
                    data: data,
                    response: response,
                    request: &mutableRequest,
                    handshakeAttempts: &handshakeAttempts,
                    method: method
                ) {
                    return transmissionResponse
                }
            } catch let urlError as URLError {
                if try await handleURLError(
                    urlError,
                    method: method,
                    remainingRetries: &remainingRetries,
                    retryAttempt: &retryAttempt
                ) {
                    continue
                }
                throw APIError.mapURLError(urlError)
            } catch let apiError as APIError {
                if config.enableLogging {
                    config.logger.logError(method: method, error: apiError)
                }
                throw apiError
            } catch {
                if config.enableLogging {
                    config.logger.logError(method: method, error: error)
                }
                throw APIError.unknown(details: error.localizedDescription)
            }
        }
    }

    private func handleURLError(
        _ urlError: URLError,
        method: String,
        remainingRetries: inout Int,
        retryAttempt: inout Int
    ) async throws -> Bool {
        if config.enableLogging {
            config.logger.logError(method: method, error: urlError)
        }

        if urlError.code == .cancelled {
            if let trustError = await trustEvaluator.consumePendingError() {
                throw mapTrustError(trustError)
            }
        }

        guard remainingRetries > 0, shouldRetry(urlError) else {
            return false
        }
        let exponentialDelay: TimeInterval =
            config.retryDelay
            * pow(
                2.0,
                Double(retryAttempt)
            )
        let safeDelay: TimeInterval = min(
            max(exponentialDelay, 0),
            TimeInterval(UInt64.max) / 1_000_000_000
        )
        retryAttempt += 1
        remainingRetries -= 1
        try await clock.sleep(for: .seconds(safeDelay))
        return true
    }

    private func handleResponse(
        data: Data,
        response: URLResponse,
        request: inout URLRequest,
        handshakeAttempts: inout Int,
        method: String
    ) async throws -> TransmissionResponse? {
        let httpResponse: HTTPURLResponse = try requireHTTPResponse(response)

        // Логируем ответ если логирование включено
        if config.enableLogging {
            config.logger.logResponse(
                method: method, statusCode: httpResponse.statusCode, responseBody: data)
        }

        if try await processSessionConflictIfNeeded(
            httpResponse,
            request: &request,
            handshakeAttempts: &handshakeAttempts
        ) {
            return nil
        }

        try validateHTTPStatus(httpResponse)
        let transmissionResponse: TransmissionResponse = try decodeTransmissionResponse(from: data)

        if transmissionResponse.isError {
            let errorMessage: String = transmissionResponse.errorMessage ?? "Unknown RPC error"
            throw APIError.mapTransmissionError(errorMessage)
        }

        return transmissionResponse
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

    private func parseHandshake(
        from response: TransmissionResponse
    ) async throws -> TransmissionHandshakeResult {
        guard let arguments = response.arguments,
            case .object(let dict) = arguments
        else {
            throw APIError.decodingFailed(
                underlyingError: "Missing arguments in session-get response"
            )
        }

        guard let rpcVersionValue = dict["rpc-version"],
            case .int(let rpcVersion) = rpcVersionValue
        else {
            throw APIError.decodingFailed(
                underlyingError: "Missing or invalid rpc-version in session-get response"
            )
        }

        let serverVersionString: String?
        if case .string(let value)? = dict["version"] {
            serverVersionString = value
        } else {
            serverVersionString = nil
        }

        return TransmissionHandshakeResult(
            sessionID: await sessionStore.load(),
            rpcVersion: rpcVersion,
            minimumSupportedRpcVersion: minimumRpcVersion,
            serverVersionDescription: serverVersionString,
            isCompatible: rpcVersion >= minimumRpcVersion
        )
    }

    // MARK: - Session Methods

    public func sessionGet() async throws -> TransmissionResponse {
        try await sendRequest(method: "session-get")
    }

    public func sessionSet(arguments: AnyCodable) async throws -> TransmissionResponse {
        try await sendRequest(method: "session-set", arguments: arguments)
    }

    public func sessionStats() async throws -> TransmissionResponse {
        try await sendRequest(method: "session-stats")
    }

    public func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int) {
        let handshake: TransmissionHandshakeResult = try await performHandshake()
        return (handshake.isCompatible, handshake.rpcVersion)
    }

    public func performHandshake() async throws -> TransmissionHandshakeResult {
        let response: TransmissionResponse = try await sessionGet()
        let handshake: TransmissionHandshakeResult = try await parseHandshake(from: response)

        if config.enableLogging {
            let message: String =
                "Server RPC version: \(handshake.rpcVersion), compatible: \(handshake.isCompatible) (minimum: \(handshake.minimumSupportedRpcVersion))"
            let logMessage: Data = Data(message.utf8)
            config.logger.logResponse(
                method: "session-get", statusCode: 200, responseBody: logMessage)
        }

        guard handshake.isCompatible else {
            throw APIError.versionUnsupported(
                version: handshake.serverVersionDescription ?? "RPC v\(handshake.rpcVersion)")
        }

        return TransmissionHandshakeResult(
            sessionID: await sessionStore.load(),
            rpcVersion: handshake.rpcVersion,
            minimumSupportedRpcVersion: handshake.minimumSupportedRpcVersion,
            serverVersionDescription: handshake.serverVersionDescription,
            isCompatible: handshake.isCompatible
        )
    }

    // MARK: - Torrent Methods

    public func torrentGet(ids: [Int]?, fields: [String]?) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]

        if let ids = ids {
            arguments["ids"] = .array(ids.map { .int($0) })
        }

        if let fields = fields {
            arguments["fields"] = .array(fields.map { .string($0) })
        }

        let args: AnyCodable? = arguments.isEmpty ? nil : anyCodable(from: arguments)
        return try await sendRequest(method: "torrent-get", arguments: args)
    }

    public func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = [:]

        if let metainfo {
            let base64Payload: String = metainfo.base64EncodedString()
            arguments["metainfo"] = .string(base64Payload)
        }

        if let filename {
            arguments["filename"] = .string(filename)
        }

        guard arguments["metainfo"] != nil || arguments["filename"] != nil else {
            throw APIError.unknown(details: "torrent-add requires filename or metainfo")
        }

        if let downloadDir = downloadDir {
            arguments["download-dir"] = .string(downloadDir)
        }

        if let paused = paused {
            arguments["paused"] = .bool(paused)
        }

        if let labels = labels {
            arguments["labels"] = .array(labels.map { .string($0) })
        }

        return try await sendRequest(method: "torrent-add", arguments: anyCodable(from: arguments))
    }

    public func torrentStart(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(
            method: "torrent-start", arguments: anyCodable(from: arguments))
    }

    public func torrentStop(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(method: "torrent-stop", arguments: anyCodable(from: arguments))
    }

    public func torrentRemove(
        ids: [Int],
        deleteLocalData: Bool?
    ) async throws -> TransmissionResponse {
        var arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]

        if let deleteLocalData = deleteLocalData {
            arguments["delete-local-data"] = .bool(deleteLocalData)
        }

        return try await sendRequest(
            method: "torrent-remove", arguments: anyCodable(from: arguments))
    }

    public func torrentSet(ids: [Int], arguments: AnyCodable) async throws -> TransmissionResponse {
        var allArguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]

        // Объединяем переданные аргументы с ids
        if case .object(let dict) = arguments {
            for (key, value) in dict {
                allArguments[key] = value
            }
        }

        return try await sendRequest(
            method: "torrent-set", arguments: anyCodable(from: allArguments))
    }

    public func torrentVerify(ids: [Int]) async throws -> TransmissionResponse {
        let arguments: [String: AnyCodable] = ["ids": .array(ids.map { .int($0) })]
        return try await sendRequest(
            method: "torrent-verify", arguments: anyCodable(from: arguments))
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
}

// swiftlint:enable type_body_length
