import Foundation

// MARK: - User Preferences Repository (In-Memory)

actor InMemoryUserPreferencesRepositoryStore {
    enum Operation: Hashable {
        case load
        case updatePollingInterval
        case setAutoRefreshEnabled
        case setTelemetryEnabled
        case updateDefaultSpeedLimits
    }

    private(set) var preferences: UserPreferences
    private var failedOperations: Set<Operation> = []
    private var observers: [UUID: AsyncStream<UserPreferences>.Continuation] = [:]

    init(preferences: UserPreferences) {
        self.preferences = UserPreferences.migratedToCurrentVersion(preferences)
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
        id: UUID,
        continuation: AsyncStream<UserPreferences>.Continuation
    ) {
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeObserver(id: id)
            }
        }
    }

    func notifyObservers() {
        let current = preferences
        for continuation in observers.values {
            continuation.yield(current)
        }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
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
            observe: makeObserve(store: store)
        )
    }

    private static func makeLoad(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable () async throws -> UserPreferences {
        {
            if await store.shouldFail(.load) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(.load)
            }
            return await store.preferences
        }
    }

    private static func makeUpdatePollingInterval(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (TimeInterval) async throws -> UserPreferences {
        { interval in
            if await store.shouldFail(.updatePollingInterval) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .updatePollingInterval)
            }
            await store.update {
                $0.pollingInterval = interval
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers()
            return await store.preferences
        }
    }

    private static func makeSetAutoRefreshEnabled(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (Bool) async throws -> UserPreferences {
        { isEnabled in
            if await store.shouldFail(.setAutoRefreshEnabled) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .setAutoRefreshEnabled)
            }
            await store.update {
                $0.isAutoRefreshEnabled = isEnabled
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers()
            return await store.preferences
        }
    }

    private static func makeSetTelemetryEnabled(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (Bool) async throws -> UserPreferences {
        { isEnabled in
            if await store.shouldFail(.setTelemetryEnabled) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .setTelemetryEnabled)
            }
            await store.update {
                $0.isTelemetryEnabled = isEnabled
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers()
            return await store.preferences
        }
    }

    private static func makeUpdateDefaultSpeedLimits(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable (UserPreferences.DefaultSpeedLimits) async throws -> UserPreferences {
        { limits in
            if await store.shouldFail(.updateDefaultSpeedLimits) {
                throw InMemoryUserPreferencesRepositoryError.operationFailed(
                    .updateDefaultSpeedLimits)
            }
            await store.update {
                $0.defaultSpeedLimits = limits
                $0.version = UserPreferences.currentVersion
            }
            await store.notifyObservers()
            return await store.preferences
        }
    }

    private static func makeObserve(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> @Sendable () -> AsyncStream<UserPreferences> {
        {
            AsyncStream { continuation in
                let id = UUID()
                Task {
                    await store.addObserver(id: id, continuation: continuation)
                }
            }
        }
    }
}

extension InMemoryUserPreferencesRepositoryStore {
    fileprivate func update(_ updateBlock: (inout UserPreferences) -> Void) {
        updateBlock(&preferences)
    }
}
