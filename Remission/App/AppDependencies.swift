import ComposableArchitecture
import Dependencies
import Foundation

enum AppDependencies {
    /// Сборка live-набора зависимостей для основной Scheме приложения.
    static func makeLive(
        namespace: AppStorageNamespace = .live()
    ) -> DependencyValues {
        var dependencies = DependencyValues.appDefault()
        let defaults = namespace.userDefaults()
        let trustStore = TransmissionTrustStore(
            serviceIdentifier: namespace.trustKeychainServiceIdentifier
        )
        let keychain = KeychainCredentialsDependency.live(
            serviceIdentifier: namespace.credentialsKeychainServiceIdentifier
        )
        let offlineCache = OfflineCacheRepository.fileBased(
            baseDirectory: ServerSnapshotStoragePaths.defaultDirectory(namespace: namespace),
            now: dependencies.dateProvider.now,
            logger: dependencies.appLogger.withCategory("offline-cache")
        )

        dependencies.transmissionClient = .placeholder
        dependencies.keychainCredentials = keychain
        dependencies.credentialsRepository = .live(
            keychain: keychain,
            auditLogger: .live(appLogger: dependencies.appLogger)
        )
        dependencies.serverConfigRepository = .fileBased(namespace: namespace)
        dependencies.userPreferencesRepository = .persistent(defaults: defaults)
        dependencies.httpWarningPreferencesStore = .userDefaults(
            suiteName: namespace.userDefaultsSuiteName)
        dependencies.onboardingProgressRepository = .userDefaults(
            suiteName: namespace.userDefaultsSuiteName)
        dependencies.transmissionTrustStoreClient = .live(store: trustStore)
        dependencies.offlineCacheRepository = offlineCache
        dependencies.serverConnectionProbe = .live(
            appLogger: dependencies.appLogger,
            trustStore: trustStore
        )
        dependencies.serverConnectionEnvironmentFactory = .live(
            credentialsRepository: dependencies.credentialsRepository,
            appClock: dependencies.appClock,
            trustPromptCenter: dependencies.transmissionTrustPromptCenter,
            appLogger: dependencies.appLogger,
            offlineCacheRepository: offlineCache,
            trustStore: trustStore
        )
        return dependencies
    }

    /// Набор зависимостей для SwiftUI превью.
    static func makePreview() -> DependencyValues {
        var dependencies = DependencyValues.appPreview()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        dependencies.userPreferencesRepository = .previewValue
        dependencies.offlineCacheRepository = .previewValue
        return dependencies
    }

    /// Базовый набор зависимостей для тестов (TestStore, unit).
    static func makeTestDefaults() -> DependencyValues {
        var dependencies = DependencyValues.appTest()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
        dependencies.serverConnectionEnvironmentFactory = .previewValue
        // Tests should not crash on notifications unless they assert against them.
        dependencies.notificationClient = .previewValue
        dependencies.userPreferencesRepository = .testValue
        dependencies.offlineCacheRepository = .testValue
        return dependencies
    }
}
