import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

/// Репозиторий, отвечающий за хранение состояния онбординга и пользовательских решений
/// относительно предупреждений безопасности.
struct OnboardingProgressRepository: Sendable {
    var hasCompletedOnboarding: @Sendable () -> Bool
    var setCompletedOnboarding: @Sendable (Bool) -> Void
    var isInsecureWarningAcknowledged: @Sendable (String) -> Bool
    var acknowledgeInsecureWarning: @Sendable (String) -> Void
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
        static let warningPrefix: String = "onboarding.warning."
    }

    /// Реализация поверх `UserDefaults`, используемая в live/preview окружениях.
    static func userDefaults(
        defaults: UserDefaults = .standard,
        completedKey: String = Keys.completed,
        warningPrefix: String = Keys.warningPrefix
    ) -> OnboardingProgressRepository {
        let storage = UserDefaultsBox(defaults: defaults)
        return OnboardingProgressRepository(
            hasCompletedOnboarding: {
                storage.defaults.bool(forKey: completedKey)
            },
            setCompletedOnboarding: { isCompleted in
                storage.defaults.set(isCompleted, forKey: completedKey)
            },
            isInsecureWarningAcknowledged: { fingerprint in
                storage.defaults.bool(forKey: warningPrefix + fingerprint)
            },
            acknowledgeInsecureWarning: { fingerprint in
                storage.defaults.set(true, forKey: warningPrefix + fingerprint)
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
            },
            isInsecureWarningAcknowledged: { fingerprint in
                store.fingerprints.contains(fingerprint)
            },
            acknowledgeInsecureWarning: { fingerprint in
                store.fingerprints.insert(fingerprint)
            }
        )
    }
}

private final class OnboardingProgressMemoryStore: @unchecked Sendable {
    private let lock = NSLock()
    private var _completed: Bool = false
    private var _fingerprints: Set<String> = []

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

    var fingerprints: Set<String> {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _fingerprints
        }
        set {
            lock.lock()
            _fingerprints = newValue
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
