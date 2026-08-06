import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Хранилище "не предупреждать про HTTP" на уровне конкретного сервера.
struct HttpWarningPreferencesStore: Sendable {
    var isSuppressed: @Sendable (String) async -> Bool
    var setSuppressed: @Sendable (String, Bool) async -> Void
    var reset: @Sendable (String) async -> Void
}

#if canImport(ComposableArchitecture)
    extension HttpWarningPreferencesStore: DependencyKey {
        static var liveValue: HttpWarningPreferencesStore {
            .userDefaults(suiteName: AppStorageNamespace.live().userDefaultsSuiteName)
        }
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
        suiteName: String? = nil
    ) -> HttpWarningPreferencesStore {
        let store = UserDefaultsStore<[String: Bool]>(
            key: Keys.prefix + "store", suiteName: suiteName)
        return HttpWarningPreferencesStore(
            isSuppressed: { fingerprint in
                await store.load()?[fingerprint] ?? false
            },
            setSuppressed: { fingerprint, value in
                var current = await store.load() ?? [:]
                current[fingerprint] = value
                try? await store.save(current)
            },
            reset: { fingerprint in
                var current = await store.load() ?? [:]
                current.removeValue(forKey: fingerprint)
                try? await store.save(current)
            }
        )
    }

    static func inMemory() -> HttpWarningPreferencesStore {
        let store = InMemoryHttpWarningStore()

        return HttpWarningPreferencesStore(
            isSuppressed: { fingerprint in
                await store.isSuppressed(fingerprint)
            },
            setSuppressed: { fingerprint, value in
                await store.setSuppressed(fingerprint, value)
            },
            reset: { fingerprint in
                await store.reset(fingerprint)
            }
        )
    }
}

/// Простое in-memory хранилище для тестов.
private actor InMemoryHttpWarningStore {
    private var storage: [String: Bool] = [:]

    func isSuppressed(_ fingerprint: String) -> Bool {
        storage[fingerprint] ?? false
    }

    func setSuppressed(_ fingerprint: String, _ value: Bool) {
        storage[fingerprint] = value
    }

    func reset(_ fingerprint: String) {
        storage.removeValue(forKey: fingerprint)
    }
}
