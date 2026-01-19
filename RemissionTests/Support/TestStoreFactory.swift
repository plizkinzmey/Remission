import ComposableArchitecture
import Dependencies
import Foundation

@testable import Remission

@MainActor
enum TestStoreFactory {
    /// Собирает базовый набор зависимостей, используемый во всех тестах:
    /// `appClock`, `mainQueueExecutor`, `dateProvider`, `uuidGenerator` и `transmissionClient`.
    private static func configureDefaults(in dependencies: inout DependencyValues) {
        dependencies = AppDependencies.makeTestDefaults()
    }

    /// Универсальный билд `TestStore` для любого редьюсера проекта.
    ///
    /// `configure` поддерживает оба подхода TCA 1.x:
    /// 1. Точечные переопределения `dependencies.someClient = ...`
    /// 2. Полная подмена `dependencies = .testDependenciesWithOverrides { ... }`
    /// поэтому можно выбирать удобный стиль без дополнительных обёрток.
    static func make<R: Reducer>(
        initialState: @autoclosure () -> R.State,
        reducer: @escaping () -> R,
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<R> {
        let store = TestStore(initialState: initialState()) {
            reducer()
        } withDependencies: { dependencies in
            configureDefaults(in: &dependencies)
            configure(&dependencies)
        }
        store.exhaustivity = .off
        return store
    }

    /// Упрощённая фабрика для `AppReducer`, избавляющая от дублирования state/reducer и ветки `withDependencies`.
    static func makeAppTestStore(
        initialState: @autoclosure () -> AppReducer.State = .init(),
        reducer: @escaping () -> AppReducer = { AppReducer() },
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<AppReducer> {
        make(initialState: initialState(), reducer: reducer, configure: configure)
    }

    /// Упрощённая фабрика для `ServerListReducer`, чтобы сократить boilerplate в фичевых тестах.
    static func makeServerListTestStore(
        initialState: @autoclosure () -> ServerListReducer.State = .init(),
        reducer: @escaping () -> ServerListReducer = { ServerListReducer() },
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<ServerListReducer> {
        make(initialState: initialState(), reducer: reducer, configure: configure)
    }

    /// Специализированная фабрика для SettingsReducer с управляемым сторам преференсов.
    static func makeSettingsTestStore(
        initialState: @autoclosure () -> SettingsReducer.State,
        preferencesStore: InMemoryUserPreferencesRepositoryStore =
            DomainFixtures.makeUserPreferencesStore(),
        serverID: UUID,
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<SettingsReducer> {
        _ = serverID
        make(
            initialState: initialState(),
            reducer: { SettingsReducer() },
            configure: { dependencies in
                dependencies.userPreferencesRepository = .inMemory(store: preferencesStore)
                configure(&dependencies)
            }
        )
    }
}
