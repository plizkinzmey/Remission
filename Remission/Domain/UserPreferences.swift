import Foundation

/// Пользовательские настройки приложения Remission.
/// Хранят значения, влияющие на периодичность обновлений и дефолтные лимиты скоростей.
struct UserPreferences: Equatable, Sendable, Codable {
    struct DefaultSpeedLimits: Equatable, Sendable, Codable {
        /// Значение лимита скачивания в КБ/с. `nil` означает отсутствие ограничения.
        var downloadKilobytesPerSecond: Int?
        /// Значение лимита отдачи в КБ/с. `nil` означает отсутствие ограничения.
        var uploadKilobytesPerSecond: Int?

        public init(
            downloadKilobytesPerSecond: Int?,
            uploadKilobytesPerSecond: Int?
        ) {
            self.downloadKilobytesPerSecond = downloadKilobytesPerSecond
            self.uploadKilobytesPerSecond = uploadKilobytesPerSecond
        }
    }

    /// Интервал опроса (в секундах) списка торрентов.
    var pollingInterval: TimeInterval
    /// Автоматическое обновление при запуске приложения.
    var isAutoRefreshEnabled: Bool
    /// Дефолтные лимиты скоростей, применяемые при добавлении торрентов.
    var defaultSpeedLimits: DefaultSpeedLimits

    public init(
        pollingInterval: TimeInterval,
        isAutoRefreshEnabled: Bool,
        defaultSpeedLimits: DefaultSpeedLimits
    ) {
        self.pollingInterval = pollingInterval
        self.isAutoRefreshEnabled = isAutoRefreshEnabled
        self.defaultSpeedLimits = defaultSpeedLimits
    }
}

extension UserPreferences {
    /// Значения по умолчанию для превью и первоначальной инициализации.
    static let `default`: UserPreferences = .init(
        pollingInterval: 5,
        isAutoRefreshEnabled: true,
        defaultSpeedLimits: .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: nil
        )
    )
}
