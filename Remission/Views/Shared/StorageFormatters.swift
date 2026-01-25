import Foundation

/// Форматтеры для отображения метрик хранилища в UI.
///
/// Это тонкая обёртка над `TorrentDataFormatter`, чтобы:
/// - иметь единое место входа для форматирования storage-значений в представлениях;
/// - при необходимости расширить форматирование, не трогая все view.
enum StorageFormatters {
    /// Форматирует байты для UI (например, "1,2 ГБ").
    /// Делегирует в `TorrentDataFormatter.bytes`, чтобы поведение было единым.
    static func bytes(_ bytes: Int64) -> String {
        TorrentDataFormatter.bytes(bytes)
    }
}
