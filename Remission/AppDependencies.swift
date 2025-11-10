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
        return dependencies
    }

    /// Базовый набор зависимостей для тестов (TestStore, unit).
    static func makeTestDefaults() -> DependencyValues {
        var dependencies = DependencyValues.appTest()
        dependencies.transmissionClient = .placeholder
        dependencies.credentialsRepository = .previewMock()
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
