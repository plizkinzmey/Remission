import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Контракт доступа к пользовательским настройкам Remission.
protocol UserPreferencesRepositoryProtocol: Sendable {
    func load() async throws -> UserPreferences
    func updatePollingInterval(_ interval: TimeInterval) async throws -> UserPreferences
    func setAutoRefreshEnabled(_ isEnabled: Bool) async throws -> UserPreferences
    func updateDefaultSpeedLimits(
        _ limits: UserPreferences.DefaultSpeedLimits
    ) async throws -> UserPreferences
}

/// Обёртка, предоставляющая зависимости через `DependencyKey`.
struct UserPreferencesRepository: Sendable, UserPreferencesRepositoryProtocol {
    var loadClosure: @Sendable () async throws -> UserPreferences
    var updatePollingIntervalClosure: @Sendable (TimeInterval) async throws -> UserPreferences
    var setAutoRefreshEnabledClosure: @Sendable (Bool) async throws -> UserPreferences
    var updateDefaultSpeedLimitsClosure:
        @Sendable (UserPreferences.DefaultSpeedLimits) async throws -> UserPreferences

    init(
        load: @escaping @Sendable () async throws -> UserPreferences,
        updatePollingInterval: @escaping @Sendable (TimeInterval) async throws -> UserPreferences,
        setAutoRefreshEnabled: @escaping @Sendable (Bool) async throws -> UserPreferences,
        updateDefaultSpeedLimits:
            @escaping @Sendable (UserPreferences.DefaultSpeedLimits)
            async throws -> UserPreferences
    ) {
        self.loadClosure = load
        self.updatePollingIntervalClosure = updatePollingInterval
        self.setAutoRefreshEnabledClosure = setAutoRefreshEnabled
        self.updateDefaultSpeedLimitsClosure = updateDefaultSpeedLimits
    }

    func load() async throws -> UserPreferences {
        try await loadClosure()
    }

    func updatePollingInterval(_ interval: TimeInterval) async throws -> UserPreferences {
        try await updatePollingIntervalClosure(interval)
    }

    func setAutoRefreshEnabled(_ isEnabled: Bool) async throws -> UserPreferences {
        try await setAutoRefreshEnabledClosure(isEnabled)
    }

    func updateDefaultSpeedLimits(
        _ limits: UserPreferences.DefaultSpeedLimits
    ) async throws -> UserPreferences {
        try await updateDefaultSpeedLimitsClosure(limits)
    }
}

#if canImport(ComposableArchitecture)
    extension UserPreferencesRepository: DependencyKey {
        static let liveValue: UserPreferencesRepository = .unimplemented
        static var previewValue: UserPreferencesRepository {
            .inMemory(
                store: InMemoryUserPreferencesRepositoryStore(
                    preferences: .default
                )
            )
        }
        static var testValue: UserPreferencesRepository {
            .inMemory(
                store: InMemoryUserPreferencesRepositoryStore(
                    preferences: .default
                )
            )
        }
    }

    extension DependencyValues {
        var userPreferencesRepository: UserPreferencesRepository {
            get { self[UserPreferencesRepository.self] }
            set { self[UserPreferencesRepository.self] = newValue }
        }
    }
#endif

extension UserPreferencesRepository {
    static let placeholder: UserPreferencesRepository = UserPreferencesRepository(
        load: { .default },
        updatePollingInterval: { interval in
            var preferences: UserPreferences = .default
            preferences.pollingInterval = interval
            return preferences
        },
        setAutoRefreshEnabled: { isEnabled in
            var preferences: UserPreferences = .default
            preferences.isAutoRefreshEnabled = isEnabled
            return preferences
        },
        updateDefaultSpeedLimits: { limits in
            var preferences: UserPreferences = .default
            preferences.defaultSpeedLimits = limits
            return preferences
        }
    )

    static let unimplemented: UserPreferencesRepository = UserPreferencesRepository(
        load: {
            throw UserPreferencesRepositoryError.notConfigured("load")
        },
        updatePollingInterval: { _ in
            throw UserPreferencesRepositoryError.notConfigured("updatePollingInterval")
        },
        setAutoRefreshEnabled: { _ in
            throw UserPreferencesRepositoryError.notConfigured("setAutoRefreshEnabled")
        },
        updateDefaultSpeedLimits: { _ in
            throw UserPreferencesRepositoryError.notConfigured("updateDefaultSpeedLimits")
        }
    )
}

private enum UserPreferencesRepositoryError: Error, LocalizedError, Sendable {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let name):
            return "UserPreferencesRepository.\(name) is not configured for this environment."
        }
    }
}
