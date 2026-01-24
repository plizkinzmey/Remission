import Foundation

/// Унифицированная утилита для маскирования чувствительных данных в логах.
enum DataMasker {
    /// Маскирует строку, оставляя видимыми первые и последние символы.
    /// Пример: "password" -> "p••••••rd"
    static func mask(_ string: String, visibleCount: Int = 1) -> String {
        guard string.count > (visibleCount * 2) else {
            return string.isEmpty ? "<empty>" : "••••"
        }
        let first = string.prefix(visibleCount)
        let last = string.suffix(visibleCount)
        return "\(first)••••\(last)"
    }

    /// Маскирует заголовок Authorization (Basic Auth).
    /// Формат: "Basic <base64>" -> "Basic dXNl••••c3dk"
    static func maskAuthHeader(_ authHeader: String) -> String {
        let lower = authHeader.lowercased()
        guard lower.hasPrefix("basic ") else {
            return mask(authHeader, visibleCount: 4)
        }

        let components = authHeader.split(
            separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2 else {
            return "Basic ••••"
        }

        let scheme = String(components[0])
        let credentials = String(components[1])
        return "\(scheme) \(mask(credentials, visibleCount: 4))"
    }

    /// Маскирует Transmission Session ID.
    static func maskSessionID(_ sessionID: String) -> String {
        mask(sessionID, visibleCount: 4)
    }
}
