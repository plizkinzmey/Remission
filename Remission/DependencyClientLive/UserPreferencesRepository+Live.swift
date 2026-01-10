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
            load: { serverID in
                try await store.load(serverID: serverID)
            },
            updatePollingInterval: { serverID, interval in
                try await store.update(serverID: serverID) { preferences in
                    preferences.pollingInterval = interval
                }
            },
            setAutoRefreshEnabled: { serverID, isEnabled in
                try await store.update(serverID: serverID) { preferences in
                    preferences.isAutoRefreshEnabled = isEnabled
                }
            },
            setTelemetryEnabled: { serverID, isEnabled in
                try await store.update(serverID: serverID) { preferences in
                    preferences.isTelemetryEnabled = isEnabled
                }
            },
            updateDefaultSpeedLimits: { serverID, limits in
                try await store.update(serverID: serverID) { preferences in
                    preferences.defaultSpeedLimits = limits
                }
            },
            updateRecentDownloadDirectories: { serverID, directories in
                try await store.update(serverID: serverID) { preferences in
                    preferences.recentDownloadDirectories = directories
                }
            },
            observe: { serverID in
                store.observe(serverID: serverID)
            }
        )
    }
}

/// Хранилище пользовательских настроек с поддержкой наблюдения изменений.
actor PersistentUserPreferencesStore {
    private enum StorageKey {
        static let legacyPreferences = "user_preferences"
        static let preferencesByServer = "user_preferences_by_server"
    }

    private let defaults: PreferencesUserDefaultsBox
    private var preferencesByServer: [UUID: UserPreferences]
    private var legacyPreferences: UserPreferences?
    private var observers: [UUID: [UUID: AsyncStream<UserPreferences>.Continuation]] = [:]

    init(
        defaults: PreferencesUserDefaultsBox = PreferencesUserDefaultsBox(defaults: .standard),
        resetStoredValue: Bool = false
    ) {
        self.defaults = defaults
        if resetStoredValue {
            defaults.remove(StorageKey.legacyPreferences)
            defaults.remove(StorageKey.preferencesByServer)
        }
        let snapshot = Self.loadSnapshot(defaults: defaults)
        self.preferencesByServer = snapshot.preferencesByServer
        self.legacyPreferences = snapshot.legacyPreferences
    }

    func load(serverID: UUID) async throws -> UserPreferences {
        let current = currentPreferences(for: serverID)
        if preferencesByServer[serverID] == nil {
            preferencesByServer[serverID] = current
            try persist(preferencesByServer)
        }
        return current
    }

    func update(
        serverID: UUID,
        _ transform: (inout UserPreferences) -> Void
    ) async throws -> UserPreferences {
        var current = currentPreferences(for: serverID)
        transform(&current)
        current.version = UserPreferences.currentVersion
        preferencesByServer[serverID] = current
        try persist(preferencesByServer)
        notifyObservers(serverID: serverID, preferences: current)
        return current
    }

    nonisolated func observe(serverID: UUID) -> AsyncStream<UserPreferences> {
        AsyncStream { continuation in
            let id = UUID()
            Task { [weak self] in
                guard let self else { return }
                await self.addObserver(
                    serverID: serverID,
                    id: id,
                    continuation: continuation
                )
            }
        }
    }

    private func addObserver(
        serverID: UUID,
        id: UUID,
        continuation: AsyncStream<UserPreferences>.Continuation
    ) {
        observers[serverID, default: [:]][id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeObserver(id: id) }
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

    private func notifyObservers(
        serverID: UUID,
        preferences: UserPreferences
    ) {
        for continuation in observers[serverID, default: [:]].values {
            continuation.yield(preferences)
        }
    }

    private func persist(_ preferencesByServer: [UUID: UserPreferences]) throws {
        let encoded = preferencesByServer.reduce(into: [String: UserPreferences]()) {
            $0[$1.key.uuidString] = $1.value
        }
        let data = try JSONEncoder().encode(encoded)
        defaults.set(data, forKey: StorageKey.preferencesByServer)
    }

    private func currentPreferences(for serverID: UUID) -> UserPreferences {
        if let existing = preferencesByServer[serverID] {
            return UserPreferences.migratedToCurrentVersion(existing)
        }
        if let legacy = legacyPreferences {
            return UserPreferences.migratedToCurrentVersion(legacy)
        }
        return .default
    }

    private static func loadSnapshot(
        defaults: PreferencesUserDefaultsBox
    ) -> (preferencesByServer: [UUID: UserPreferences], legacyPreferences: UserPreferences?) {
        var result: [UUID: UserPreferences] = [:]
        if let data = defaults.data(StorageKey.preferencesByServer) {
            if let decoded = try? JSONDecoder().decode(
                [String: UserPreferences].self,
                from: data
            ) {
                for (key, value) in decoded {
                    if let id = UUID(uuidString: key) {
                        result[id] = UserPreferences.migratedToCurrentVersion(value)
                    }
                }
            }
        }

        var legacy: UserPreferences?
        if let data = defaults.data(StorageKey.legacyPreferences) {
            if let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
                legacy = UserPreferences.migratedToCurrentVersion(decoded)
            }
        }

        return (result, legacy)
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
