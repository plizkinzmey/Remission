import ComposableArchitecture
import Dependencies
import Foundation

@testable import Remission

enum TestStoreFactory {
    @MainActor
    static func makeTestStore<State, Action>(
        initialState: State,
        reducer: some Reducer<State, Action>,
        configure: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStore<State, Action> {
        TestStore(initialState: initialState) {
            reducer
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
            configure(&$0)
        }
    }
}
