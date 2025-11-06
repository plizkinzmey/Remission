import ComposableArchitecture
import Dependencies
import Foundation

@testable import Remission

@MainActor
enum TestStoreFactory {
    /// Создаёт TestStore с дефолтным набором зависимостей из AppDependencies.
    static func make<R: Reducer>(
        initialState: @autoclosure () -> R.State,
        reducer: @escaping () -> R,
        configure: @Sendable (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<R> {
        TestStore(initialState: initialState()) {
            reducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            configure(&dependencies)
        }
    }
}
