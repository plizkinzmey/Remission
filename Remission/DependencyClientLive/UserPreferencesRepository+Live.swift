import Foundation

extension UserPreferencesRepository {
    /// Живая реализация репозитория предпочтений с сохранением в `UserDefaults`.
    static func persistent(
        store: PersistentUserPreferencesStore = PersistentUserPreferencesStore()
    ) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: {
                try await store.load()
            },
            updatePollingInterval: { interval in
                try await store.update { preferences in
                    preferences.pollingInterval = interval
                }
            },
            setAutoRefreshEnabled: { isEnabled in
                try await store.update { preferences in
                    preferences.isAutoRefreshEnabled = isEnabled
                }
            },
            updateDefaultSpeedLimits: { limits in
                try await store.update { preferences in
                    preferences.defaultSpeedLimits = limits
                }
            },
            observe: {
                store.observe()
            }
        )
    }
}

/// Хранилище пользовательских настроек с поддержкой наблюдения изменений.
actor PersistentUserPreferencesStore {
    private enum StorageKey {
        static let preferences = "user_preferences"
    }

    private let defaults: UserDefaults
    private var preferences: UserPreferences
    private var observers: [UUID: AsyncStream<UserPreferences>.Continuation] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preferences = Self.loadSnapshot(defaults: defaults)
    }

    func load() async throws -> UserPreferences {
        preferences
    }

    func update(_ transform: (inout UserPreferences) -> Void) async throws -> UserPreferences {
        transform(&preferences)
        try persist(preferences)
        notifyObservers()
        return preferences
    }

    nonisolated func observe() -> AsyncStream<UserPreferences> {
        AsyncStream { continuation in
            let id = UUID()
            Task { [weak self] in
                guard let self else { return }
                await self.addObserver(id: id, continuation: continuation)
            }
        }
    }

    private func addObserver(
        id: UUID,
        continuation: AsyncStream<UserPreferences>.Continuation
    ) {
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeObserver(id: id) }
        }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }

    private func notifyObservers() {
        let current = preferences
        for continuation in observers.values {
            continuation.yield(current)
        }
    }

    private func persist(_ preferences: UserPreferences) throws {
        let data = try JSONEncoder().encode(preferences)
        defaults.set(data, forKey: StorageKey.preferences)
    }

    private static func loadSnapshot(defaults: UserDefaults) -> UserPreferences {
        guard let data = defaults.data(forKey: StorageKey.preferences) else {
            return .default
        }
        do {
            return try JSONDecoder().decode(UserPreferences.self, from: data)
        } catch {
            defaults.removeObject(forKey: StorageKey.preferences)
            return .default
        }
    }
}
