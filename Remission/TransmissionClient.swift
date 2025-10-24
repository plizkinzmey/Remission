import Foundation

// swiftlint:disable type_body_length

/// Конкретная реализация TransmissionClientProtocol.
/// Использует URLSession для отправки HTTP запросов к Transmission RPC API.
/// Обрабатывает аутентификацию (Basic Auth + HTTP 409 session-id handshake),
/// парсирование ответов и ошибки согласно Transmission RPC специфике (не JSON-RPC 2.0).
public final class TransmissionClient: TransmissionClientProtocol, Sendable {
    /// Минимально поддерживаемая версия RPC (Transmission 3.0 соответствует 14).
    private let minimumRpcVersion: Int = 14

    /// Конфигурация клиента (базовый URL, credentials, таймауты).
    private let config: TransmissionClientConfig

    /// Lock для безопасного доступа к session ID
    nonisolated private let sessionIDLock: NSLock = NSLock()

    /// Переменная для хранения текущего session ID (защищена sessionIDLock)
    nonisolated(unsafe) private var _sessionID: String?

    /// URLSession для выполнения HTTP запросов.
    private let session: URLSession

    /// Инициализация TransmissionClient с конфигурацией.
    ///
    /// - Parameters:
    ///   - config: Конфигурация (baseURL, credentials, таймауты).
    ///   - session: URLSession для HTTP запросов (по умолчанию `URLSession.shared`).
    public init(config: TransmissionClientConfig, session: URLSession = URLSession.shared) {
        self.config = config
        self.session = session
        self._sessionID = nil
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

        // Добавляем Basic Auth если нужен
        if let username = config.username, let password = config.password {
            let credentials: String = "\(username):\(password)"
            let base64Credentials: String? = credentials.data(using: .utf8)?.base64EncodedString()
            if let base64Credentials: String = base64Credentials {
                urlRequest.setValue(
                    "Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }

        // Добавляем session ID если уже есть
        if let sessionID = getSessionID() {
            urlRequest.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id")
        }

        urlRequest.httpBody = jsonData

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

                if let transmissionResponse = try handleResponse(
                    data: data,
                    response: response,
                    request: &mutableRequest,
                    handshakeAttempts: &handshakeAttempts,
                    method: method
                ) {
                    return transmissionResponse
                }
            } catch let urlError as URLError {
                if config.enableLogging {
                    config.logger.logError(method: method, error: urlError)
                }
                if remainingRetries > 0, shouldRetry(urlError) {
                    let exponentialDelay: TimeInterval =
                        config.retryDelay * pow(2.0, Double(retryAttempt))
                    let safeDelay: TimeInterval = min(
                        max(exponentialDelay, 0),
                        TimeInterval(UInt64.max) / 1_000_000_000
                    )
                    retryAttempt += 1
                    remainingRetries -= 1
                    let nanoseconds: UInt64 = UInt64(safeDelay * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
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

    private func handleResponse(
        data: Data,
        response: URLResponse,
        request: inout URLRequest,
        handshakeAttempts: inout Int,
        method: String
    ) throws -> TransmissionResponse? {
        let httpResponse: HTTPURLResponse = try requireHTTPResponse(response)

        // Логируем ответ если логирование включено
        if config.enableLogging {
            config.logger.logResponse(
                method: method, statusCode: httpResponse.statusCode, responseBody: data)
        }

        if try processSessionConflictIfNeeded(
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
    ) throws -> Bool {
        guard httpResponse.statusCode == 409 else {
            return false
        }

        handshakeAttempts += 1
        guard handshakeAttempts <= 2 else {
            throw APIError.sessionConflict
        }

        guard
            let sessionIDFromHeader: String =
                httpResponse.value(forHTTPHeaderField: "X-Transmission-Session-Id")
        else {
            throw APIError.sessionConflict
        }

        setSessionID(sessionIDFromHeader)
        request.setValue(sessionIDFromHeader, forHTTPHeaderField: "X-Transmission-Session-Id")
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

    /// Получить текущий session ID (потокобезопасно).
    nonisolated private func getSessionID() -> String? {
        sessionIDLock.lock()
        defer { sessionIDLock.unlock() }
        return _sessionID
    }

    /// Установить session ID (потокобезопасно).
    nonisolated private func setSessionID(_ sessionID: String) {
        sessionIDLock.lock()
        defer { sessionIDLock.unlock() }
        self._sessionID = sessionID
    }

    private func parseHandshake(from response: TransmissionResponse) throws
        -> TransmissionHandshakeResult
    {
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
        if let versionValue = dict["version"],
            case .string(let value) = versionValue
        {
            serverVersionString = value
        } else {
            serverVersionString = nil
        }

        return TransmissionHandshakeResult(
            sessionID: getSessionID(),
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
        let handshake: TransmissionHandshakeResult = try parseHandshake(from: response)

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
            sessionID: getSessionID(),
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
