import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
    import DependenciesMacros
#endif

/// Контракт доступа к пользовательским настройкам Remission.
protocol UserPreferencesRepositoryProtocol: Sendable {
    func load(serverID: UUID) async throws -> UserPreferences
    func updatePollingInterval(
        serverID: UUID,
        _ interval: TimeInterval
    ) async throws -> UserPreferences
    func setAutoRefreshEnabled(
        serverID: UUID,
        _ isEnabled: Bool
    ) async throws -> UserPreferences
    func setTelemetryEnabled(
        serverID: UUID,
        _ isEnabled: Bool
    ) async throws -> UserPreferences
    func updateDefaultSpeedLimits(
        serverID: UUID,
        _ limits: UserPreferences.DefaultSpeedLimits
    ) async throws -> UserPreferences
    func updateRecentDownloadDirectories(
        serverID: UUID,
        _ directories: [String]
    ) async throws -> UserPreferences
    /// Наблюдает за изменениями настроек и возвращает поток актуальных значений.
    func observe(serverID: UUID) -> AsyncStream<UserPreferences>
}

/// Обёртка, предоставляющая зависимости через `DependencyKey`.
struct UserPreferencesRepository: Sendable, UserPreferencesRepositoryProtocol {
    var loadClosure: @Sendable (UUID) async throws -> UserPreferences
    var updatePollingIntervalClosure: @Sendable (UUID, TimeInterval) async throws -> UserPreferences
    var setAutoRefreshEnabledClosure: @Sendable (UUID, Bool) async throws -> UserPreferences
    var setTelemetryEnabledClosure: @Sendable (UUID, Bool) async throws -> UserPreferences
    var updateDefaultSpeedLimitsClosure:
        @Sendable (UUID, UserPreferences.DefaultSpeedLimits) async throws -> UserPreferences
    var updateRecentDownloadDirectoriesClosure:
        @Sendable (UUID, [String]) async throws -> UserPreferences
    var observeClosure: @Sendable (UUID) -> AsyncStream<UserPreferences>

    init(
        load: @escaping @Sendable (UUID) async throws -> UserPreferences,
        updatePollingInterval:
            @escaping @Sendable (UUID, TimeInterval) async throws
            -> UserPreferences,
        setAutoRefreshEnabled: @escaping @Sendable (UUID, Bool) async throws -> UserPreferences,
        setTelemetryEnabled: @escaping @Sendable (UUID, Bool) async throws -> UserPreferences,
        updateDefaultSpeedLimits:
            @escaping @Sendable (UUID, UserPreferences.DefaultSpeedLimits)
            async throws -> UserPreferences,
        updateRecentDownloadDirectories:
            @escaping @Sendable (UUID, [String]) async throws -> UserPreferences,
        observe: @escaping @Sendable (UUID) -> AsyncStream<UserPreferences>
    ) {
        self.loadClosure = load
        self.updatePollingIntervalClosure = updatePollingInterval
        self.setAutoRefreshEnabledClosure = setAutoRefreshEnabled
        self.setTelemetryEnabledClosure = setTelemetryEnabled
        self.updateDefaultSpeedLimitsClosure = updateDefaultSpeedLimits
        self.updateRecentDownloadDirectoriesClosure = updateRecentDownloadDirectories
        self.observeClosure = observe
    }

    func load(serverID: UUID) async throws -> UserPreferences {
        try await loadClosure(serverID)
    }

    func updatePollingInterval(
        serverID: UUID,
        _ interval: TimeInterval
    ) async throws -> UserPreferences {
        try await updatePollingIntervalClosure(serverID, interval)
    }

    func setAutoRefreshEnabled(
        serverID: UUID,
        _ isEnabled: Bool
    ) async throws -> UserPreferences {
        try await setAutoRefreshEnabledClosure(serverID, isEnabled)
    }

    func setTelemetryEnabled(
        serverID: UUID,
        _ isEnabled: Bool
    ) async throws -> UserPreferences {
        try await setTelemetryEnabledClosure(serverID, isEnabled)
    }

    func updateDefaultSpeedLimits(
        serverID: UUID,
        _ limits: UserPreferences.DefaultSpeedLimits
    ) async throws -> UserPreferences {
        try await updateDefaultSpeedLimitsClosure(serverID, limits)
    }

    func updateRecentDownloadDirectories(
        serverID: UUID,
        _ directories: [String]
    ) async throws -> UserPreferences {
        try await updateRecentDownloadDirectoriesClosure(serverID, directories)
    }

    func observe(serverID: UUID) -> AsyncStream<UserPreferences> {
        observeClosure(serverID)
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
        var isTelemetryEnabled: @Sendable (UUID) async throws -> Bool = { _ in false }
        var observeTelemetryEnabled: @Sendable (UUID) -> AsyncStream<Bool> = { _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    }

    extension TelemetryConsentDependency {
        static let placeholder: Self = Self(
            isTelemetryEnabled: { _ in false },
            observeTelemetryEnabled: { _ in
                AsyncStream { continuation in
                    continuation.finish()
                }
            }
        )
    }

    extension TelemetryConsentDependency: DependencyKey {
        static let liveValue: Self = Self(
            isTelemetryEnabled: { serverID in
                @Dependency(\.userPreferencesRepository) var userPreferencesRepository
                let repository = userPreferencesRepository
                let preferences = try await repository.load(serverID: serverID)
                return preferences.isTelemetryEnabled
            },
            observeTelemetryEnabled: { serverID in
                @Dependency(\.userPreferencesRepository) var userPreferencesRepository
                let repository = userPreferencesRepository
                return AsyncStream { continuation in
                    let task = Task {
                        if let initial = try? await repository.load(serverID: serverID) {
                            continuation.yield(initial.isTelemetryEnabled)
                        }
                        let stream = repository.observe(serverID: serverID)
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
        load: { _ in .default },
        updatePollingInterval: { _, interval in
            var preferences: UserPreferences = .default
            preferences.pollingInterval = interval
            return preferences
        },
        setAutoRefreshEnabled: { _, isEnabled in
            var preferences: UserPreferences = .default
            preferences.isAutoRefreshEnabled = isEnabled
            return preferences
        },
        setTelemetryEnabled: { _, isEnabled in
            var preferences: UserPreferences = .default
            preferences.isTelemetryEnabled = isEnabled
            return preferences
        },
        updateDefaultSpeedLimits: { _, limits in
            var preferences: UserPreferences = .default
            preferences.defaultSpeedLimits = limits
            return preferences
        },
        updateRecentDownloadDirectories: { _, directories in
            var preferences: UserPreferences = .default
            preferences.recentDownloadDirectories = directories
            return preferences
        },
        observe: { _ in
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    )

    static let unimplemented: UserPreferencesRepository = UserPreferencesRepository(
        load: { _ in
            throw UserPreferencesRepositoryError.notConfigured("load")
        },
        updatePollingInterval: { _, _ in
            throw UserPreferencesRepositoryError.notConfigured("updatePollingInterval")
        },
        setAutoRefreshEnabled: { _, _ in
            throw UserPreferencesRepositoryError.notConfigured("setAutoRefreshEnabled")
        },
        setTelemetryEnabled: { _, _ in
            throw UserPreferencesRepositoryError.notConfigured("setTelemetryEnabled")
        },
        updateDefaultSpeedLimits: { _, _ in
            throw UserPreferencesRepositoryError.notConfigured("updateDefaultSpeedLimits")
        },
        updateRecentDownloadDirectories: { _, _ in
            throw UserPreferencesRepositoryError.notConfigured("updateRecentDownloadDirectories")
        },
        observe: { _ in
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
