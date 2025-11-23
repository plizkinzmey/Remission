import Foundation

public enum TransmissionLogLevel: String, Sendable {
    case debug
    case info
    case warning
    case error
}

public struct TransmissionLogContext: Sendable, Equatable {
    public var serverID: UUID?
    public var host: String?
    public var path: String?
    public var method: String?
    public var statusCode: Int?
    public var durationMs: Double?
    public var retryAttempt: Int?
    public var maxRetries: Int?

    public init(
        serverID: UUID? = nil,
        host: String? = nil,
        path: String? = nil,
        method: String? = nil,
        statusCode: Int? = nil,
        durationMs: Double? = nil,
        retryAttempt: Int? = nil,
        maxRetries: Int? = nil
    ) {
        self.serverID = serverID
        self.host = host
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.retryAttempt = retryAttempt
        self.maxRetries = maxRetries
    }

    func merging(_ other: TransmissionLogContext) -> TransmissionLogContext {
        TransmissionLogContext(
            serverID: other.serverID ?? serverID,
            host: other.host ?? host,
            path: other.path ?? path,
            method: other.method ?? method,
            statusCode: other.statusCode ?? statusCode,
            durationMs: other.durationMs ?? durationMs,
            retryAttempt: other.retryAttempt ?? retryAttempt,
            maxRetries: other.maxRetries ?? maxRetries
        )
    }

    func maskedServerID() -> String {
        guard let id = serverID else { return "<unknown>" }
        return String(id.uuidString.prefix(8))
    }

    func metadata() -> [String: String] {
        var result: [String: String] = [:]
        if let host {
            result["host"] = host
        }
        if let path {
            result["path"] = path
        }
        if let method {
            result["method"] = method
        }
        if let statusCode {
            result["status"] = "\(statusCode)"
        }
        if let durationMs {
            let rounded = Int(durationMs.rounded())
            result["elapsed_ms"] = "\(rounded)"
        }
        if let retryAttempt {
            result["retry_attempt"] = "\(retryAttempt)"
        }
        if let maxRetries {
            result["max_retries"] = "\(maxRetries)"
        }
        result["server"] = maskedServerID()
        return result
    }
}

/// Протокол для логирования запросов/ответов Transmission RPC.
/// Реализует безопасное логирование с маскированием чувствительных данных.
public protocol TransmissionLogger: Sendable {
    func logRequest(
        method: String,
        request: URLRequest,
        context: TransmissionLogContext
    )

    func logResponse(
        method: String,
        statusCode: Int,
        responseBody: Data,
        context: TransmissionLogContext
    )

    func logError(
        method: String,
        error: Error,
        context: TransmissionLogContext
    )
}

/// Стандартная реализация логирования.
/// Маскирует Authorization заголовки и X-Transmission-Session-Id, не раскрывает содержимое JSON,
/// усекает слишком длинные данные. Потокобезопасна и не требует главного потока.
public final class DefaultTransmissionLogger: TransmissionLogger, Sendable {
    private let appLogger: AppLogger?
    /// Функция логирования (по умолчанию print).
    private let logFn: @Sendable (String) -> Void
    private let baseContext: TransmissionLogContext

    /// Инициализация с пользовательской функцией логирования.
    /// - Parameters:
    ///   - appLogger: Опциональный AppLogger для единообразных уровней.
    ///   - baseContext: Базовый контекст (server/host/path), дополняется контекстом вызова.
    ///   - logFn: Функция для вывода логов (по умолчанию print).
    public init(
        appLogger: AppLogger? = nil,
        baseContext: TransmissionLogContext = .init(),
        logFn: @escaping @Sendable (String) -> Void = { print($0) }
    ) {
        self.appLogger = appLogger
        self.baseContext = baseContext
        self.logFn = logFn
    }

    public func logRequest(
        method: String,
        request: URLRequest,
        context: TransmissionLogContext
    ) {
        let mergedContext = baseContext.merging(context)
        let maskedRequest: URLRequest = maskRequest(request)
        let headers: String = formatHeaders(maskedRequest.allHTTPHeaderFields ?? [:])
        let urlDescription: String = maskedRequest.url?.absoluteString ?? "<no-url>"
        let message =
            "[debug] [Transmission] request method=\(method) url=\(urlDescription) headers=\(headers) meta=\(formatMetadata(mergedContext))"
        emit(level: .debug, message: message, metadata: mergedContext.metadata())
    }

    public func logResponse(
        method: String,
        statusCode: Int,
        responseBody: Data,
        context: TransmissionLogContext
    ) {
        let mergedContext = baseContext.merging(context)
        let bodySummary: String = sanitizeResponseBody(responseBody)
        let level: TransmissionLogLevel = (200...299).contains(statusCode) ? .info : .warning
        let message =
            "[\(level.rawValue)] [Transmission] response method=\(method) status=\(statusCode) body=\(bodySummary) meta=\(formatMetadata(mergedContext))"
        emit(level: level, message: message, metadata: mergedContext.metadata())
    }

    public func logError(
        method: String,
        error: Error,
        context: TransmissionLogContext
    ) {
        let mergedContext = baseContext.merging(context)
        let errorDescription = safeErrorDescription(error)
        let message =
            "[error] [Transmission] error method=\(method) message=\(errorDescription) meta=\(formatMetadata(mergedContext))"
        emit(level: .error, message: message, metadata: mergedContext.metadata())
    }

    // MARK: - Private Helpers

    private func emit(
        level: TransmissionLogLevel,
        message: String,
        metadata: [String: String]
    ) {
        if let appLogger {
            switch level {
            case .debug:
                appLogger.debug(message, metadata: metadata)
            case .info:
                appLogger.info(message, metadata: metadata)
            case .warning:
                appLogger.warning(message, metadata: metadata)
            case .error:
                appLogger.error(message, metadata: metadata)
            }
        } else {
            logFn(message)
        }
    }

    /// Замаскировать чувствительные заголовки в запросе.
    private func maskRequest(_ request: URLRequest) -> URLRequest {
        var masked: URLRequest = request
        if let headers: [String: String] = masked.allHTTPHeaderFields {
            var maskedHeaders: [String: String] = headers
            if let auth: String = maskedHeaders["Authorization"] {
                maskedHeaders["Authorization"] = maskAuthHeader(auth)
            }
            if let sessionId: String = maskedHeaders["X-Transmission-Session-Id"] {
                maskedHeaders["X-Transmission-Session-Id"] = maskSessionID(sessionId)
            }
            masked.allHTTPHeaderFields = maskedHeaders
        }
        return masked
    }

    /// Маскировать Authorization header (Basic Auth).
    /// Входящий формат: "Basic <base64(username:password)>"
    /// Выходящий формат: "Basic <first-3-chars>..."
    private func maskAuthHeader(_ authHeader: String) -> String {
        let lower: String = authHeader.lowercased()
        guard lower.hasPrefix("basic ") else {
            let visiblePrefix: String = String(authHeader.prefix(6))
            let visibleSuffix: String = String(authHeader.suffix(2))
            return "\(visiblePrefix)...\(visibleSuffix)"
        }

        let components: [Substring] = authHeader.split(
            separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2 else {
            return "Basic ..."
        }

        let scheme: String = String(components[0])  // "Basic"
        let credentials: String = String(components[1])

        if credentials.count <= 8 {
            return "\(scheme) ..."
        }

        let first: String = String(credentials.prefix(4))
        let last: String = String(credentials.suffix(4))
        return "\(scheme) \(first)...\(last)"
    }

    /// Маскировать Session ID.
    /// Показать только первые 4 и последние 4 символа.
    private func maskSessionID(_ sessionID: String) -> String {
        guard sessionID.count > 8 else {
            return "****"
        }
        let first: String = String(sessionID.prefix(4))
        let last: String = String(sessionID.suffix(4))
        return "\(first)...\(last)"
    }

    /// Форматировать заголовки для логирования.
    private func formatHeaders(_ headers: [String: String]) -> String {
        let headerStrings: [String] = headers.map { key, value in
            "\(key): \(value)"
        }
        return "[\(headerStrings.joined(separator: ", "))]"
    }

    /// Сформировать безопасное представление тела ответа.
    /// Показывает только структуру JSON, не раскрывая конкретные значения.
    private func sanitizeResponseBody(_ data: Data) -> String {
        guard data.isEmpty == false else {
            return "<empty body>"
        }

        do {
            let jsonObject: Any = try JSONSerialization.jsonObject(with: data)
            let summary: String = summarizeJSON(jsonObject, depth: 0)
            return truncateIfNeeded(summary, maxLength: 200)
        } catch {
            return "<\(data.count) bytes>"
        }
    }

    /// Сформировать краткое описание JSON-структуры.
    private func summarizeJSON(_ value: Any, depth: Int) -> String {
        if depth >= 2 {
            return describeShallow(value)
        }

        switch value {
        case let dictionary as [String: Any]:
            let components: [String] =
                dictionary
                .sorted { $0.key < $1.key }
                .map { key, value in
                    "\(key): \(summarizeJSON(value, depth: depth + 1))"
                }
            return "{\(components.joined(separator: ", "))}"
        case let array as [Any]:
            return "array(count: \(array.count))"
        default:
            return describeShallow(value)
        }
    }

    /// Описание значения без раскрытия чувствительных данных.
    private func describeShallow(_ value: Any) -> String {
        switch value {
        case let array as [Any]:
            return "array(count: \(array.count))"
        case let dictionary as [String: Any]:
            return "{keys: \(dictionary.keys.sorted())}"
        case is Bool:
            return "<redacted bool>"
        case is String:
            return "<redacted string>"
        case is NSNumber:
            return "<redacted number>"
        case is NSNull:
            return "null"
        default:
            return "<\(type(of: value))>"
        }
    }

    /// Усечение строки если она слишком длинная.
    private func truncateIfNeeded(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else {
            return string
        }
        let prefix: Substring = string.prefix(maxLength)
        return String(prefix) + "... (truncated)"
    }

    private func formatMetadata(_ context: TransmissionLogContext) -> String {
        let elements: [String] = context.metadata()
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
        return elements.isEmpty ? "<none>" : elements.joined(separator: " ")
    }

    private func safeErrorDescription(_ error: Error) -> String {
        let description = String(describing: error)
        return truncateIfNeeded(
            description.replacingOccurrences(of: "\n", with: " "), maxLength: 180)
    }
}

/// Нейтральная реализация логирования (ничего не логирует).
public final class NoOpTransmissionLogger: TransmissionLogger, Sendable {
    public static let shared: NoOpTransmissionLogger = NoOpTransmissionLogger()

    public func logRequest(
        method: String,
        request: URLRequest,
        context: TransmissionLogContext
    ) {}

    public func logResponse(
        method: String,
        statusCode: Int,
        responseBody: Data,
        context: TransmissionLogContext
    ) {}

    public func logError(method: String, error: Error, context: TransmissionLogContext) {}
}
