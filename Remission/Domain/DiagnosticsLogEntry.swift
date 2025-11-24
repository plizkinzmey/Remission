import Foundation

/// Модель записи диагностического лога для отображения в UI.
public struct DiagnosticsLogEntry: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var level: AppLogLevel
    public var message: String
    public var category: String
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date,
        level: AppLogLevel,
        message: String,
        category: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.category = category
        self.metadata = metadata
    }
}

/// Фильтр для выборки логов по уровню и текстовому запросу.
public struct DiagnosticsLogFilter: Equatable, Sendable {
    public var level: AppLogLevel?
    public var searchText: String = ""

    public func matches(_ entry: DiagnosticsLogEntry) -> Bool {
        if let level, entry.level != level {
            return false
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return true }

        let query = trimmedQuery.lowercased()
        if entry.message.lowercased().contains(query) {
            return true
        }

        if entry.category.lowercased().contains(query) {
            return true
        }

        return entry.metadata.values.contains { value in
            value.lowercased().contains(query)
        }
    }
}
