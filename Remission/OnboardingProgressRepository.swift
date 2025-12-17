import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Репозиторий, отвечающий за хранение состояния прохождения онбординга.
struct OnboardingProgressRepository: Sendable {
    var hasCompletedOnboarding: @Sendable () -> Bool
    var setCompletedOnboarding: @Sendable (Bool) -> Void
}

#if canImport(ComposableArchitecture)
    extension OnboardingProgressRepository: DependencyKey {
        static let liveValue: OnboardingProgressRepository = .userDefaults()
        static let previewValue: OnboardingProgressRepository = .userDefaults()
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

    /// Реализация поверх `UserDefaults`, используемая в live/preview окружениях.
    static func userDefaults(
        defaults: UserDefaults = .standard,
        completedKey: String = Keys.completed
    ) -> OnboardingProgressRepository {
        let storage = UserDefaultsBox(defaults: defaults)
        return OnboardingProgressRepository(
            hasCompletedOnboarding: {
                storage.defaults.bool(forKey: completedKey)
            },
            setCompletedOnboarding: { isCompleted in
                storage.defaults.set(isCompleted, forKey: completedKey)
            }
        )
    }

    /// In-memory реализация, применяемая в тестах.
    static func inMemory() -> OnboardingProgressRepository {
        let store = OnboardingProgressMemoryStore()

        return OnboardingProgressRepository(
            hasCompletedOnboarding: {
                store.completed
            },
            setCompletedOnboarding: { isCompleted in
                store.completed = isCompleted
            }
        )
    }
}

private final class OnboardingProgressMemoryStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _completed: Bool = false

    var completed: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _completed
        }
        set {
            lock.lock()
            _completed = newValue
            lock.unlock()
        }
    }
}

private final class UserDefaultsBox: @unchecked Sendable {
    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
}
