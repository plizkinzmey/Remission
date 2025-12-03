import Foundation

/// Утилиты для безопасного отображения и копирования записей диагностики.
enum DiagnosticsLogFormatter {
    private static let sensitiveKeywords: [String] = [
        "auth", "token", "password", "session", "cookie", "secret", "credential"
    ]

    private static let offlineKeywords: [String] = [
        "notconnectedtointernet",
        "networkconnectionlost",
        "timedout",
        "dns",
        "cannotfindhost",
        "cannotconnecttohost",
        "datanotallowed",
        "secureconnectionfailed",
        "offline",
        "connectionappears",
        "noroute",
        "network is down"
    ]

    static func sanitizedMetadata(_ metadata: [String: String]) -> [String: String] {
        metadata.compactMapValues { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            return trimmed
        }
        .filter { key, _ in
            let lowered = key.lowercased()
            return sensitiveKeywords.contains(where: { lowered.contains($0) }) == false
        }
    }

    static func metadataTags(for entry: DiagnosticsLogEntry) -> [String] {
        let metadata = sanitizedMetadata(entry.metadata)
        var highlights: [String] = []

        if let method = metadata["method"] {
            highlights.append(method)
        }
        if let status = metadata["status"] {
            highlights.append("status \(status)")
        }
        if let host = metadata["host"] {
            highlights.append(host)
        }
        if let path = metadata["path"] {
            highlights.append(path)
        }
        if let server = metadata["server"] {
            highlights.append("server \(server)")
        }
        if let elapsed = metadata["elapsed_ms"] {
            highlights.append("\(elapsed) ms")
        }
        if let retryAttempt = metadata["retry_attempt"] {
            highlights.append("retry #\(retryAttempt)")
        }
        let hasRetry = highlights.contains { $0.hasPrefix("retry") }
        if let maxRetries = metadata["max_retries"], hasRetry {
            highlights.append("max \(maxRetries)")
        }
        return highlights
    }

    static func errorSummary(for entry: DiagnosticsLogEntry) -> String? {
        guard let raw = sanitizedMetadata(entry.metadata)["error"], raw.isEmpty == false else {
            return nil
        }
        return truncate(raw, limit: 160)
    }

    static func isOffline(_ entry: DiagnosticsLogEntry) -> Bool {
        let haystack: String = offlineSource(for: entry).lowercased()
        let normalized = haystack.replacingOccurrences(of: " ", with: "")
        return offlineKeywords.contains { keyword in
            haystack.contains(keyword) || normalized.contains(keyword)
        }
    }

    static func isNetworkIssue(_ entry: DiagnosticsLogEntry) -> Bool {
        if isOffline(entry) { return true }
        let statusValue = sanitizedMetadata(entry.metadata)["status"].flatMap(Int.init)
        if let status = statusValue, status >= 400 {
            return true
        }
        if sanitizedMetadata(entry.metadata)["error"] != nil {
            return true
        }
        return false
    }

    static func copyText(for entry: DiagnosticsLogEntry) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: entry.timestamp)
        let metadata = sanitizedMetadata(entry.metadata)
        let metadataChunk: String =
            metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\(truncate($0.value, limit: 120))" }
            .joined(separator: "; ")

        let header = "[\(timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)]"
        let base = "\(header) \(entry.message)"
        guard metadataChunk.isEmpty == false else { return base }
        return "\(base) { \(metadataChunk) }"
    }

    static func copyText(for entries: [DiagnosticsLogEntry]) -> String {
        entries
            .sorted(by: { $0.timestamp > $1.timestamp })
            .map { copyText(for: $0) }
            .joined(separator: "\n")
    }

    // MARK: - Private helpers

    private static func offlineSource(for entry: DiagnosticsLogEntry) -> String {
        sanitizedMetadata(entry.metadata)["error"] ?? entry.message
    }

    private static func truncate(_ value: String, limit: Int) -> String {
        guard value.count > limit else { return value }
        let prefix = value.prefix(limit)
        return "\(prefix)…"
    }
}
