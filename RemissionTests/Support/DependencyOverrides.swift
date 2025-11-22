import Dependencies

@testable import Remission

/// Распределённые шаблоны переопределения зависимостей для тестов и превью.
///
/// Используйте эти утилиты вместе с `TestStoreFactory` и `Store(... ) withDependencies:` чтобы избежать повторения boilerplate.
extension DependencyValues {
    /// Базовый набор зависимостей для SwiftUI превью с моками `CredentialsRepository` и `TransmissionClient`.
    ///
    /// ```swift
    /// Store(initialState: sampleState()) {
    ///     AppReducer()
    /// } withDependencies: {
    ///     $0 = .previewDependenciesWithMocks {
    ///         $0.transmissionClient = .previewMock(sessionGet: {
    ///             TransmissionResponse(result: "preview")
    ///         })
    ///     }
    /// }
    /// ```
    static func previewDependenciesWithMocks(
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> DependencyValues {
        var dependencies = AppDependencies.makePreview()
        dependencies.credentialsRepository = .previewMock()
        dependencies.transmissionClient = .previewMock()
        configure(&dependencies)
        return dependencies
    }

    /// Упрощённый способ собрать `DependencyValues` для тестов, включая стандартные моки, и затем дополнительно переопределить нужные зависимости.
    ///
    /// ```swift
    /// let store = TestStoreFactory.makeAppTestStore(configure: { dependencies in
    ///     dependencies = .testDependenciesWithOverrides {
    ///         $0.transmissionClient = .previewMock(sessionGet: { ... })
    ///     }
    /// })
    /// ```
    static func testDependenciesWithOverrides(
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> DependencyValues {
        var dependencies = AppDependencies.makeTestDefaults()
        configure(&dependencies)
        return dependencies
    }

    /// Набор зависимостей с переопределённым in-memory `UserPreferencesRepository`.
    ///
    /// Удобно использовать в тестах, где требуется управлять состоянием преференсов через
    /// `InMemoryUserPreferencesRepositoryStore` (например, для инъекции ошибок).
    static func testDependencies(
        userPreferencesStore: InMemoryUserPreferencesRepositoryStore,
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> DependencyValues {
        var dependencies = AppDependencies.makeTestDefaults()
        dependencies.userPreferencesRepository = .inMemory(store: userPreferencesStore)
        configure(&dependencies)
        return dependencies
    }
}
