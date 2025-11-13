import ComposableArchitecture
import Dependencies
import Foundation

enum AppDependencies {
    /// Сборка live-набора зависимостей для основной Scheме приложения.
    static func makeLive() -> DependencyValues {
        var dependencies = DependencyValues.appDefault()
        dependencies.transmissionClient = TransmissionClientBootstrap.makeLiveDependency(
            dependencies: dependencies
        )
        return dependencies
    }

    /// Набор зависимостей для SwiftUI превью.
    static func makePreview() -> DependencyValues {
        var dependencies = DependencyValues.appPreview()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        return dependencies
    }

    /// Базовый набор зависимостей для тестов (TestStore, unit).
    static func makeTestDefaults() -> DependencyValues {
        var dependencies = DependencyValues.appTest()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        return dependencies
    }

    /// Набор зависимостей для UI-тестов с управляемыми сценариями.
    static func makeUITest(scenario: AppBootstrap.UITestingScenario?) -> DependencyValues {
        var dependencies = DependencyValues.appTest()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = CredentialsRepository.uiTestInMemory()
        dependencies.serverConfigRepository = .inMemory(initial: [])
        dependencies.onboardingProgressRepository = .inMemory()
        dependencies.httpWarningPreferencesStore = .inMemory()
        dependencies.serverConnectionEnvironmentFactory = .previewValue

        switch scenario {
        case .onboardingFlow:
            dependencies.serverConnectionProbe = .uiTestOnboardingMock()
        case .serverListSample:
            dependencies.serverConfigRepository = .inMemory(
                initial: AppBootstrap.serverListSampleServers()
            )
            dependencies.onboardingProgressRepository = OnboardingProgressRepository(
                hasCompletedOnboarding: { true },
                setCompletedOnboarding: { _ in }
            )
        case .none:
            break
        }

        return dependencies
    }
}

extension DependencyValues {
    /// Значения по умолчанию для рабочей сборки.
    static func appDefault() -> DependencyValues {
        var dependencies = DependencyValues()
        dependencies.useAppDefaults()
        return dependencies
    }

    /// Набор значений для SwiftUI превью.
    static func appPreview() -> DependencyValues {
        var dependencies = DependencyValues()
        dependencies.useAppDefaults()
        dependencies.appClock = .placeholder
        dependencies.mainQueueExecutor = .placeholder
        dependencies.dateProvider = .placeholder
        dependencies.uuidGenerator = .placeholder
        dependencies.httpWarningPreferencesStore = .inMemory()
        dependencies.transmissionTrustStoreClient = .placeholder
        dependencies.serverConnectionProbe = .placeholder
        return dependencies
    }

    /// Набор значений для тестов.
    static func appTest() -> DependencyValues {
        var dependencies = DependencyValues()
        dependencies.useAppDefaults()
        dependencies.appClock = .placeholder
        dependencies.mainQueueExecutor = .placeholder
        dependencies.dateProvider = .placeholder
        dependencies.uuidGenerator = .placeholder
        dependencies.httpWarningPreferencesStore = .inMemory()
        dependencies.transmissionTrustStoreClient = .placeholder
        dependencies.serverConnectionProbe = .placeholder
        return dependencies
    }

    /// Применяет дефолтные зависимости проекта.
    mutating func useAppDefaults() {
        appClock = AppClockDependency.liveValue
        mainQueueExecutor = MainQueueDependency.liveValue
        dateProvider = DateProviderDependency.liveValue
        uuidGenerator = UUIDGeneratorDependency.liveValue
    }
}

extension TransmissionServerCredentialsKey {
    static var preview: TransmissionServerCredentialsKey {
        TransmissionServerCredentialsKey(
            host: "preview.remote",
            port: 9091,
            isSecure: false,
            username: "remission-preview"
        )
    }
}

extension TransmissionServerCredentials {
    static var preview: TransmissionServerCredentials {
        TransmissionServerCredentials(
            key: .preview,
            password: "preview-password"
        )
    }
}

extension CredentialsRepository {
    /// In-memory реализация для UI-тестов, исключающая обращения к Keychain.
    static func uiTestInMemory() -> CredentialsRepository {
        let store = UITestCredentialsStore()
        return CredentialsRepository(
            save: { credentials in
                await store.save(credentials)
            },
            load: { key in
                await store.load(key)
            },
            delete: { key in
                await store.delete(key)
            }
        )
    }
}

private actor UITestCredentialsStore {
    private var storage: [TransmissionServerCredentialsKey: TransmissionServerCredentials] = [:]

    func save(_ credentials: TransmissionServerCredentials) {
        storage[credentials.key] = credentials
    }

    func load(_ key: TransmissionServerCredentialsKey) -> TransmissionServerCredentials? {
        storage[key]
    }

    func delete(_ key: TransmissionServerCredentialsKey) {
        storage[key] = nil
    }
}

extension CredentialsRepository {
    static func previewMock(
        load:
            @Sendable @escaping (TransmissionServerCredentialsKey) async throws ->
            TransmissionServerCredentials? = { _ in .preview },
        save: @Sendable @escaping (TransmissionServerCredentials) async throws -> Void = { _ in },
        delete: @Sendable @escaping (TransmissionServerCredentialsKey) async throws -> Void = { _ in
        }
    ) -> CredentialsRepository {
        CredentialsRepository(save: save, load: load, delete: delete)
    }
}

extension TransmissionClientDependency {
    static func previewMock(
        sessionGet: @Sendable @escaping () async throws -> TransmissionResponse = {
            TransmissionResponse(result: "success")
        }
    ) -> TransmissionClientDependency {
        var dependency = TransmissionClientDependency.placeholder
        dependency.sessionGet = sessionGet
        return dependency
    }
}
