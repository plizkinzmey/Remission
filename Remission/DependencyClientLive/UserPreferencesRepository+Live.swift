import Foundation

extension UserPreferencesRepository {
    /// Живая реализация репозитория предпочтений с сохранением в `UserDefaults`.
    static func persistent(
        defaults: UserDefaults = .standard,
        resetStoredValue: Bool = false
    ) -> UserPreferencesRepository {
        let defaultsBox = PreferencesUserDefaultsBox(defaults: defaults)
        let store = PersistentUserPreferencesStore(
            defaults: defaultsBox,
            resetStoredValue: resetStoredValue
        )
        return persistent(store: store)
    }

    static func persistent(
        store: PersistentUserPreferencesStore
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
            setTelemetryEnabled: { isEnabled in
                try await store.update { preferences in
                    preferences.isTelemetryEnabled = isEnabled
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

    private let defaults: PreferencesUserDefaultsBox
    private var preferences: UserPreferences
    private var observers: [UUID: AsyncStream<UserPreferences>.Continuation] = [:]

    init(
        defaults: PreferencesUserDefaultsBox = PreferencesUserDefaultsBox(defaults: .standard),
        resetStoredValue: Bool = false
    ) {
        self.defaults = defaults
        if resetStoredValue {
            defaults.remove(StorageKey.preferences)
        }
        self.preferences = Self.loadSnapshot(defaults: defaults)
    }

    func load() async throws -> UserPreferences {
        preferences
    }

    func update(_ transform: (inout UserPreferences) -> Void) async throws -> UserPreferences {
        transform(&preferences)
        preferences.version = UserPreferences.currentVersion
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

    private static func loadSnapshot(defaults: PreferencesUserDefaultsBox) -> UserPreferences {
        guard let data = defaults.data(StorageKey.preferences) else {
            return .default
        }
        do {
            let decoded = try JSONDecoder().decode(UserPreferences.self, from: data)
            return migrate(decoded, defaults: defaults)
        } catch {
            defaults.remove(StorageKey.preferences)
            return .default
        }
    }

    private static func migrate(
        _ preferences: UserPreferences,
        defaults: PreferencesUserDefaultsBox
    ) -> UserPreferences {
        var migrated = preferences
        var didMigrate = false

        if migrated.version < UserPreferences.currentVersion {
            migrated.isTelemetryEnabled = false
            migrated.version = UserPreferences.currentVersion
            didMigrate = true
        }

        if didMigrate {
            do {
                let data = try JSONEncoder().encode(migrated)
                defaults.set(data, forKey: StorageKey.preferences)
            } catch {
                defaults.remove(StorageKey.preferences)
                return .default
            }
        }

        return migrated
    }
}

final class PreferencesUserDefaultsBox: @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func data(_ key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data, forKey key: String) {
        defaults.set(data, forKey: key)
    }

    func remove(_ key: String) {
        defaults.removeObject(forKey: key)
    }
}
