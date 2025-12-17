import Foundation

/// Пользовательские настройки приложения Remission.
/// Хранят значения, влияющие на периодичность обновлений и дефолтные лимиты скоростей.
struct UserPreferences: Equatable, Sendable, Codable {
    static let currentVersion: Int = 2

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

    /// Версия схемы сохранённых настроек. Помогает мигрировать данные при изменении структуры.
    var version: Int
    /// Интервал опроса (в секундах) списка торрентов.
    var pollingInterval: TimeInterval
    /// Автоматическое обновление при запуске приложения.
    var isAutoRefreshEnabled: Bool
    /// Явное согласие пользователя на отправку телеметрии.
    var isTelemetryEnabled: Bool
    /// Дефолтные лимиты скоростей, применяемые при добавлении торрентов.
    var defaultSpeedLimits: DefaultSpeedLimits

    private enum CodingKeys: String, CodingKey {
        case version
        case pollingInterval
        case isAutoRefreshEnabled
        case isTelemetryEnabled
        case defaultSpeedLimits
    }

    public init(
        pollingInterval: TimeInterval,
        isAutoRefreshEnabled: Bool,
        isTelemetryEnabled: Bool,
        defaultSpeedLimits: DefaultSpeedLimits,
        version: Int = UserPreferences.currentVersion
    ) {
        self.version = version
        self.pollingInterval = pollingInterval
        self.isAutoRefreshEnabled = isAutoRefreshEnabled
        self.isTelemetryEnabled = isTelemetryEnabled
        self.defaultSpeedLimits = defaultSpeedLimits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version =
            try container.decodeIfPresent(Int.self, forKey: .version)
            ?? UserPreferences.currentVersion
        self.version = version
        self.pollingInterval = try container.decode(TimeInterval.self, forKey: .pollingInterval)
        self.isAutoRefreshEnabled = try container.decode(Bool.self, forKey: .isAutoRefreshEnabled)
        self.isTelemetryEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .isTelemetryEnabled) ?? false
        self.defaultSpeedLimits = try container.decode(
            DefaultSpeedLimits.self,
            forKey: .defaultSpeedLimits
        )
    }
}

extension UserPreferences {
    /// Значения по умолчанию для превью и первоначальной инициализации.
    static let `default`: UserPreferences = .init(
        pollingInterval: 5,
        isAutoRefreshEnabled: true,
        isTelemetryEnabled: false,
        defaultSpeedLimits: .init(
            downloadKilobytesPerSecond: nil,
            uploadKilobytesPerSecond: nil
        ),
        version: UserPreferences.currentVersion
    )
}

extension UserPreferences {
    /// Приводит сохранённые настройки к актуальной версии схемы.
    static func migratedToCurrentVersion(_ preferences: UserPreferences) -> UserPreferences {
        var migrated = preferences

        if migrated.version < 2 {
            migrated.isTelemetryEnabled = false
        }

        if migrated.version < UserPreferences.currentVersion {
            migrated.version = UserPreferences.currentVersion
        }

        return migrated
    }
}
