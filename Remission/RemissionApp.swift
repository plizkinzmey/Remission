import ComposableArchitecture
import SwiftUI

@main
struct RemissionApp: App {
    @StateObject private var store: StoreOf<AppReducer>

    init() {
        _store = StateObject(
            wrappedValue: Store(initialState: AppReducer.State()) {
                AppReducer()
            }
        )
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
