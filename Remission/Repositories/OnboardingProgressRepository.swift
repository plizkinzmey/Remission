import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Репозиторий, отвечающий за хранение состояния прохождения онбординга.
struct OnboardingProgressRepository: Sendable {
    var hasCompletedOnboarding: @Sendable () async -> Bool
    var setCompletedOnboarding: @Sendable (Bool) async -> Void
}

#if canImport(ComposableArchitecture)
    extension OnboardingProgressRepository: DependencyKey {
        static var liveValue: OnboardingProgressRepository {
            .userDefaults(suiteName: AppStorageNamespace.live().userDefaultsSuiteName)
        }
        static var previewValue: OnboardingProgressRepository {
            .userDefaults(suiteName: AppStorageNamespace.live().userDefaultsSuiteName)
        }
        static let testValue: OnboardingProgressRepository = .inMemory()
    }

    extension DependencyValues {
        var onboardingProgressRepository: OnboardingProgressRepository {
            get { self[OnboardingProgressRepository.self] }
            set { self[OnboardingProgressRepository.self] = newValue }
        }
    }
#endif

extension OnboardingProgressRepository {
    private enum Keys {
        static let completed: String = "onboarding.completed"
    }

    /// Реализация поверх `UserDefaultsStore` (actor-based), используемая в live/preview окружениях.
    static func userDefaults(
        suiteName: String? = nil,
        completedKey: String = Keys.completed
    ) -> OnboardingProgressRepository {
        let store = UserDefaultsStore<Bool>(key: completedKey, suiteName: suiteName)
        return OnboardingProgressRepository(
            hasCompletedOnboarding: {
                await store.load() ?? false
            },
            setCompletedOnboarding: { isCompleted in
                try? await store.save(isCompleted)
            }
        )
    }

    /// In-memory реализация, применяемая в тестах.
    static func inMemory() -> OnboardingProgressRepository {
        let store = InMemoryStore<Bool>(initialValue: false)

        return OnboardingProgressRepository(
            hasCompletedOnboarding: {
                await store.load()
            },
            setCompletedOnboarding: { isCompleted in
                await store.save(isCompleted)
            }
        )
    }
}

/// Простое in-memory хранилище для тестов.
private actor InMemoryStore<Value: Sendable> {
    private var value: Value

    init(initialValue: Value) {
        self.value = initialValue
    }

    func load() -> Value {
        value
    }

    func save(_ newValue: Value) {
        value = newValue
    }
}
