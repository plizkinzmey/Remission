import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
#endif

/// Контракт доступа к пользовательским настройкам Remission.
protocol UserPreferencesRepositoryProtocol: Sendable {
    func load() async throws -> UserPreferences
    func updatePollingInterval(_ interval: TimeInterval) async throws -> UserPreferences
    func setAutoRefreshEnabled(_ isEnabled: Bool) async throws -> UserPreferences
    func setTelemetryEnabled(_ isEnabled: Bool) async throws -> UserPreferences
    func updateDefaultSpeedLimits(
        _ limits: UserPreferences.DefaultSpeedLimits
    ) async throws -> UserPreferences
    /// Наблюдает за изменениями настроек и возвращает поток актуальных значений.
    func observe() -> AsyncStream<UserPreferences>
}

/// Обёртка, предоставляющая зависимости через `DependencyKey`.
struct UserPreferencesRepository: Sendable, UserPreferencesRepositoryProtocol {
    var loadClosure: @Sendable () async throws -> UserPreferences
    var updatePollingIntervalClosure: @Sendable (TimeInterval) async throws -> UserPreferences
    var setAutoRefreshEnabledClosure: @Sendable (Bool) async throws -> UserPreferences
    var setTelemetryEnabledClosure: @Sendable (Bool) async throws -> UserPreferences
    var updateDefaultSpeedLimitsClosure:
        @Sendable (UserPreferences.DefaultSpeedLimits) async throws -> UserPreferences
    var observeClosure: @Sendable () -> AsyncStream<UserPreferences>

    init(
        load: @escaping @Sendable () async throws -> UserPreferences,
        updatePollingInterval: @escaping @Sendable (TimeInterval) async throws -> UserPreferences,
        setAutoRefreshEnabled: @escaping @Sendable (Bool) async throws -> UserPreferences,
        setTelemetryEnabled: @escaping @Sendable (Bool) async throws -> UserPreferences,
        updateDefaultSpeedLimits:
            @escaping @Sendable (UserPreferences.DefaultSpeedLimits)
            async throws -> UserPreferences,
        observe: @escaping @Sendable () -> AsyncStream<UserPreferences>
    ) {
        self.loadClosure = load
        self.updatePollingIntervalClosure = updatePollingInterval
        self.setAutoRefreshEnabledClosure = setAutoRefreshEnabled
        self.setTelemetryEnabledClosure = setTelemetryEnabled
        self.updateDefaultSpeedLimitsClosure = updateDefaultSpeedLimits
        self.observeClosure = observe
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

    func setTelemetryEnabled(_ isEnabled: Bool) async throws -> UserPreferences {
        try await setTelemetryEnabledClosure(isEnabled)
    }

    func updateDefaultSpeedLimits(
        _ limits: UserPreferences.DefaultSpeedLimits
    ) async throws -> UserPreferences {
        try await updateDefaultSpeedLimitsClosure(limits)
    }

    func observe() -> AsyncStream<UserPreferences> {
        observeClosure()
    }
}

#if canImport(ComposableArchitecture)
    extension UserPreferencesRepository: DependencyKey {
        static let liveValue: UserPreferencesRepository = .persistent()
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

    /// Централизованный доступ к согласию на отправку телеметрии.
    /// Используется телеметрическими клиентами, чтобы не отправлять события без опт-ина.
    @DependencyClient
    struct TelemetryConsentDependency: Sendable {
        var isTelemetryEnabled: @Sendable () async throws -> Bool = { false }
        var observeTelemetryEnabled: @Sendable () -> AsyncStream<Bool> = {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }

    extension TelemetryConsentDependency {
        static let placeholder: Self = Self(
            isTelemetryEnabled: { false },
            observeTelemetryEnabled: {
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }

    extension TelemetryConsentDependency: DependencyKey {
        static let liveValue: Self = Self(
            isTelemetryEnabled: {
                @Dependency(\.userPreferencesRepository) var userPreferencesRepository
                let repository = userPreferencesRepository
                let preferences = try await repository.load()
                return preferences.isTelemetryEnabled
            },
            observeTelemetryEnabled: {
                @Dependency(\.userPreferencesRepository) var userPreferencesRepository
                let repository = userPreferencesRepository
                return AsyncStream { continuation in
                    let task = Task {
                        if let initial = try? await repository.load() {
                            continuation.yield(initial.isTelemetryEnabled)
                        }
                        let stream = repository.observe()
                        for await preferences in stream {
                            continuation.yield(preferences.isTelemetryEnabled)
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            }
        )

        static let previewValue: Self = placeholder
        static let testValue: Self = placeholder
    }

    extension DependencyValues {
        var telemetryConsent: TelemetryConsentDependency {
            get { self[TelemetryConsentDependency.self] }
            set { self[TelemetryConsentDependency.self] = newValue }
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
        setTelemetryEnabled: { isEnabled in
            var preferences: UserPreferences = .default
            preferences.isTelemetryEnabled = isEnabled
            return preferences
        },
        updateDefaultSpeedLimits: { limits in
            var preferences: UserPreferences = .default
            preferences.defaultSpeedLimits = limits
            return preferences
        },
        observe: {
            AsyncStream { continuation in
                continuation.finish()
            }
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
        setTelemetryEnabled: { _ in
            throw UserPreferencesRepositoryError.notConfigured("setTelemetryEnabled")
        },
        updateDefaultSpeedLimits: { _ in
            throw UserPreferencesRepositoryError.notConfigured("updateDefaultSpeedLimits")
        },
        observe: {
            AsyncStream { continuation in
                continuation.finish()
            }
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
