import Foundation

/// Утилита для работы с путями Transmission.
enum TransmissionPathNormalization {
    /// Нормализует путь загрузки, объединяя его с базовой директорией сервера если нужно.
    ///
    /// - Parameters:
    ///   - destination: Введенный пользователем путь (может быть относительным или абсолютным).
    ///   - defaultDownloadDirectory: Стандартная директория загрузки сервера.
    /// - Returns: Полный нормализованный путь.
    static func normalize(
        _ destination: String,
        defaultDownloadDirectory: String
    ) -> String {
        let base = defaultDownloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard base.isEmpty == false else { return destination }

        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDestination.isEmpty == false else { return base }

        // Если путь уже выглядит как абсолютный (начинается с / и содержит несколько компонентов),
        // или если база пуста, возвращаем как есть.
        let hasNestedPath = trimmedDestination.hasPrefix("/") && trimmedDestination.dropFirst().contains("/")
        if hasNestedPath {
            return trimmedDestination
        }

        // Убираем лишние слеши по краям
        let trimmedComponent = trimmedDestination.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard trimmedComponent.isEmpty == false else { return base }

        let normalizedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        return normalizedBase + "/" + trimmedComponent
    }
}
