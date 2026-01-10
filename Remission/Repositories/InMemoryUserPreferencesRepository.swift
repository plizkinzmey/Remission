import Foundation

// MARK: - User Preferences Repository (In-Memory)

actor InMemoryUserPreferencesRepositoryStore {
    enum Operation: Hashable {
        case load
        case updatePollingInterval
        case setAutoRefreshEnabled
        case setTelemetryEnabled
        case updateDefaultSpeedLimits
        case updateRecentDownloadDirectories
    }

    private var preferencesByServer: [UUID: UserPreferences]
    private var failedOperations: Set<Operation> = []
    private var observers: [UUID: [UUID: AsyncStream<UserPreferences>.Continuation]] = [:]
    private let defaultPreferences: UserPreferences

    init(preferences: UserPreferences, serverID: UUID? = nil) {
        self.defaultPreferences = UserPreferences.migratedToCurrentVersion(preferences)
        if let serverID {
            self.preferencesByServer = [serverID: defaultPreferences]
        } else {
            self.preferencesByServer = [:]
        }
    }

    func markFailure(_ operation: Operation) {
        failedOperations.insert(operation)
    }

    func clearFailure(_ operation: Operation) {
        failedOperations.remove(operation)
    }

    func shouldFail(_ operation: Operation) -> Bool {
        failedOperations.contains(operation)
    }

    func addObserver(
        serverID: UUID,
        id: UUID,
        continuation: AsyncStream<UserPreferences>.Continuation
    ) {
        observers[serverID, default: [:]][id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeObserver(id: id)
            }
        }
    }

    func notifyObservers(serverID: UUID) {
        let current = preferences(for: serverID)
        for continuation in observers[serverID, default: [:]].values {
            continuation.yield(current)
        }
    }

    private func removeObserver(id: UUID) {
        for key in observers.keys {
            observers[key]?[id] = nil
            if observers[key]?.isEmpty == true {
                observers[key] = nil
            }
        }
    }

    func preferences(for serverID: UUID) -> UserPreferences {
        if let current = preferencesByServer[serverID] {
            return UserPreferences.migratedToCurrentVersion(current)
        }
        preferencesByServer[serverID] = defaultPreferences
        return defaultPreferences
    }

    func snapshot(serverID: UUID) -> UserPreferences {
        preferences(for: serverID)
    }

    func update(
        serverID: UUID,
        _ updateBlock: (inout UserPreferences) -> Void
    ) {
        var current = preferences(for: serverID)
        updateBlock(&current)
        preferencesByServer[serverID] = current
    }
}

enum InMemoryUserPreferencesRepositoryError: Error, LocalizedError, Sendable, Equatable {
    case operationFailed(InMemoryUserPreferencesRepositoryStore.Operation)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "InMemoryUserPreferencesRepository operation \(operation) marked as failed."
        }
    }
}

extension UserPreferencesRepository {
    static func inMemory(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: makeLoad(store: store),
            updatePollingInterval: makeUpdatePollingInterval(store: store),
            setAutoRefreshEnabled: makeSetAutoRefreshEnabled(store: store),
            setTelemetryEnabled: makeSetTelemetryEnabled(store: store),
            updateDefaultSpeedLimits: makeUpdateDefaultSpeedLimits(store: store),
            updateRecentDownloadDirectories: makeUpdateRecentDownloadDirectories(store: store),
            observe: makeObserve(store: store)
        )
    }

    private static func makeLoad(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UUID) async throws -> UserPreferences {
        { serverID in
            if await store.shouldFail(.load) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(.load)
            }
            return await store.preferences(for: serverID)
        }
    }

    private static func makeUpdatePollingInterval(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UUID, TimeInterval) async throws -> UserPreferences {
        { serverID, interval in
            if await store.shouldFail(.updatePollingInterval) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .updatePollingInterval)
            }
            await store.update(serverID: serverID) {
                $0.pollingInterval = interval
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers(serverID: serverID)
            return await store.preferences(for: serverID)
        }
    }

    private static func makeSetAutoRefreshEnabled(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UUID, Bool) async throws -> UserPreferences {
        { serverID, isEnabled in
            if await store.shouldFail(.setAutoRefreshEnabled) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .setAutoRefreshEnabled)
            }
            await store.update(serverID: serverID) {
                $0.isAutoRefreshEnabled = isEnabled
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers(serverID: serverID)
            return await store.preferences(for: serverID)
        }
    }

    private static func makeSetTelemetryEnabled(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UUID, Bool) async throws -> UserPreferences {
        { serverID, isEnabled in
            if await store.shouldFail(.setTelemetryEnabled) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .setTelemetryEnabled)
            }
            await store.update(serverID: serverID) {
                $0.isTelemetryEnabled = isEnabled
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers(serverID: serverID)
            return await store.preferences(for: serverID)
        }
    }

    private static func makeUpdateDefaultSpeedLimits(
        store: InMemoryUserPreferencesRepositoryStore
    )
        -> @Sendable (UUID, UserPreferences.DefaultSpeedLimits) async throws
        -> UserPreferences {
        { serverID, limits in
            if await store.shouldFail(.updateDefaultSpeedLimits) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .updateDefaultSpeedLimits)
            }
            await store.update(serverID: serverID) {
                $0.defaultSpeedLimits = limits
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers(serverID: serverID)
            return await store.preferences(for: serverID)
        }
    }

    private static func makeUpdateRecentDownloadDirectories(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UUID, [String]) async throws -> UserPreferences {
        { serverID, directories in
            if await store.shouldFail(.updateRecentDownloadDirectories) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .updateRecentDownloadDirectories
                )
            }
            await store.update(serverID: serverID) {
                $0.recentDownloadDirectories = directories
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers(serverID: serverID)
            return await store.preferences(for: serverID)
        }
    }

    private static func makeObserve(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UUID) -> AsyncStream<UserPreferences> {
        { serverID in
            AsyncStream { continuation in
                let id = UUID()
                Task {
                    await store.addObserver(
                        serverID: serverID,
                        id: id,
                        continuation: continuation
                    )
                }
            }
        }
    }
}
