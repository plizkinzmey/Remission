import Foundation

/// Протокол для логирования запросов/ответов Transmission RPC.
/// Реализует безопасное логирование с маскированием чувствительных данных.
public protocol TransmissionLogger: Sendable {
    /// Залогировать исходящий RPC запрос.
    /// - Parameters:
    ///   - method: Имя RPC метода (например, "torrent-get").
    ///   - request: URLRequest с заголовками и телом.
    func logRequest(method: String, request: URLRequest)

    /// Залогировать входящий RPC ответ.
    /// - Parameters:
    ///   - method: Имя RPC метода.
    ///   - statusCode: HTTP статус код.
    ///   - responseBody: Тело ответа (сырой JSON).
    func logResponse(method: String, statusCode: Int, responseBody: Data)

    /// Залогировать ошибку сети или RPC.
    /// - Parameters:
    ///   - method: Имя RPC метода.
    ///   - error: Объект ошибки.
    func logError(method: String, error: Error)
}

/// Стандартная реализация логирования в консоль.
/// Маскирует Authorization заголовки и X-Transmission-Session-Id.
/// Потокобезопасна и не требует главного потока.
public final class DefaultTransmissionLogger: TransmissionLogger, Sendable {
    /// Функция логирования (по умолчанию print).
    private let logFn: @Sendable (String) -> Void

    /// Инициализация с пользовательской функцией логирования.
    /// - Parameter logFn: Функция для вывода логов (по умолчанию print).
    public init(logFn: @escaping @Sendable (String) -> Void = { print($0) }) {
        self.logFn = logFn
    }

    public func logRequest(method: String, request: URLRequest) {
        let maskedRequest: URLRequest = maskRequest(request)
        let headers: String = formatHeaders(maskedRequest.allHTTPHeaderFields ?? [:])
        logFn(
            "🔵 [TransmissionClient] Request: \(method)\n"
                + "   URL: \(maskedRequest.url?.absoluteString ?? "<no-url>")\n"
                + "   Headers: \(headers)"
        )
    }

    public func logResponse(method: String, statusCode: Int, responseBody: Data) {
        let bodySummary: String = sanitizeResponseBody(responseBody)
        let statusEmoji: String = (200...299).contains(statusCode) ? "✅" : "⚠️"
        logFn(
            "\(statusEmoji) [TransmissionClient] Response: \(method)\n"
                + "   Status: \(statusCode)\n"
                + "   Body: \(bodySummary)"
        )
    }

    public func logError(method: String, error: Error) {
        logFn(
            "❌ [TransmissionClient] Error in \(method): \(error.localizedDescription)"
        )
    }

    // MARK: - Private Helpers

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
        // Обрабатываем как "Basic <credentials>" (без чувствительного раскрытия)
        // Если формат другой — возвращаем укороченную версию для безопасности.
        let lower: String = authHeader.lowercased()
        guard lower.hasPrefix("basic ") else {
            // Для других схем показываем только первые 6/последние 2 символа
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

        // Показываем первые 4 и последние 4 символа base64 строки, если длина позволяет
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
}

/// Нейтральная реализация логирования (ничего не логирует).
public final class NoOpTransmissionLogger: TransmissionLogger, Sendable {
    public static let shared: NoOpTransmissionLogger = NoOpTransmissionLogger()

    public func logRequest(method: String, request: URLRequest) {}

    public func logResponse(method: String, statusCode: Int, responseBody: Data) {}

    public func logError(method: String, error: Error) {}
}
