import Foundation

/// Утилита для нормализации путей назначения в стиле Transmission.
///
/// Transmission допускает как абсолютные пути, так и короткие «имена папок».
/// Эта функция приводит ввод пользователя к стабильному виду:
/// - если база сервера пустая, возвращаем ввод как есть;
/// - если ввод пустой, используем базовую директорию;
/// - если ввод уже выглядит как «вложенный абсолютный путь» (`/a/b`), не трогаем его;
/// - во всех остальных случаях трактуем ввод как компонент и добавляем к базе.
enum TransmissionPathNormalization {
    /// Нормализует путь загрузки, при необходимости объединяя его с базовой директорией сервера.
    ///
    /// Важно: мы считаем «настоящим абсолютным путём» только путь с несколькими компонентами
    /// (например, `/volume/downloads`). Короткие формы вроде `/downloads` трактуются как
    /// имя подпапки и присоединяются к базе.
    static func normalize(
        _ destination: String,
        defaultDownloadDirectory: String
    ) -> String {
        let base = defaultDownloadDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard base.isEmpty == false else { return destination }

        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDestination.isEmpty == false else { return base }

        // Если путь уже выглядит как «вложенный абсолютный» (начинается с / и содержит / внутри),
        // возвращаем как есть, чтобы не ломать явно указанные пути.
        // Считаем путь «вложенным абсолютным» только если после разбиения на компоненты
        // (без пустых сегментов) остаётся более одного компонента: `/a/b`.
        // Это защищает от ложных срабатываний на `/folder/` и `///`.
        let destinationComponents = trimmedDestination.split(separator: "/")
        let hasNestedPath = trimmedDestination.hasPrefix("/") && destinationComponents.count > 1
        if hasNestedPath {
            return trimmedDestination
        }

        // Убираем лишние слеши по краям, чтобы не получить двойные разделители.
        let trimmedComponent = trimmedDestination.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard trimmedComponent.isEmpty == false else { return base }

        // Нормализуем базу (убираем завершающий /), затем соединяем через один разделитель.
        let normalizedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
        return normalizedBase + "/" + trimmedComponent
    }
}
