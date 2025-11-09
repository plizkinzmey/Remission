import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Хранилище "не предупреждать про HTTP" на уровне конкретного сервера.
struct HttpWarningPreferencesStore: Sendable {
    var isSuppressed: @Sendable (String) -> Bool
    var setSuppressed: @Sendable (String, Bool) -> Void
    var reset: @Sendable (String) -> Void
}

#if canImport(ComposableArchitecture)
    extension HttpWarningPreferencesStore: DependencyKey {
        static let liveValue: HttpWarningPreferencesStore = .userDefaults()
        static let previewValue: HttpWarningPreferencesStore = .inMemory()
        static let testValue: HttpWarningPreferencesStore = .inMemory()
    }

    extension DependencyValues {
        var httpWarningPreferencesStore: HttpWarningPreferencesStore {
            get { self[HttpWarningPreferencesStore.self] }
            set { self[HttpWarningPreferencesStore.self] = newValue }
        }
    }
#endif

extension HttpWarningPreferencesStore {
    private enum Keys {
        static let prefix: String = "http.warning."
    }

    static func userDefaults(
        defaults: UserDefaults = .standard
    ) -> HttpWarningPreferencesStore {
        let storage = UserDefaultsBox(defaults: defaults)
        return HttpWarningPreferencesStore(
            isSuppressed: { fingerprint in
                storage.defaults.bool(forKey: Keys.prefix + fingerprint)
            },
            setSuppressed: { fingerprint, value in
                storage.defaults.set(value, forKey: Keys.prefix + fingerprint)
            },
            reset: { fingerprint in
                storage.defaults.removeObject(forKey: Keys.prefix + fingerprint)
            }
        )
    }

    static func inMemory() -> HttpWarningPreferencesStore {
        let store = HttpWarningPreferencesMemoryStore()
        return HttpWarningPreferencesStore(
            isSuppressed: { fingerprint in
                store.value(forKey: fingerprint) ?? false
            },
            setSuppressed: { fingerprint, value in
                store.set(value, forKey: fingerprint)
            },
            reset: { fingerprint in
                store.removeValue(forKey: fingerprint)
            }
        )
    }
}

private final class HttpWarningPreferencesMemoryStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Bool] = [:]

    func value(forKey key: String) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func set(_ value: Bool, forKey key: String) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }

    func removeValue(forKey key: String) {
        lock.lock()
        storage.removeValue(forKey: key)
        lock.unlock()
    }
}

private final class UserDefaultsBox: @unchecked Sendable {
    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
}
