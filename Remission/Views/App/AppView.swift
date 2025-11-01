import ComposableArchitecture
import SwiftUI

struct AppView: View {
    @Bindable var store: StoreOf<AppReducer>

    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            ServerListView(
                store: store.scope(state: \.serverList, action: \.serverList)
            )
            .navigationTitle("Remission")
            .toolbar {
                #if os(macOS)
                    ToolbarItem(placement: .primaryAction) { addServerButton }
                #else
                    ToolbarItem(placement: .topBarTrailing) { addServerButton }
                #endif
            }
        } destination: { store in
            ServerDetailView(store: store)
        }
    }

    private var addServerButton: some View {
        Button {
            store.send(.serverList(.addButtonTapped))
        } label: {
            Label("Добавить", systemImage: "plus")
        }
    }
}

#Preview("AppView Empty") {
    AppView(
        store: Store(
            initialState: AppReducer.State()
        ) {
            AppReducer()
        } withDependencies: {
            $0.transmissionClient = .testValue
        }
    )
}

#Preview("AppView Sample") {
    AppView(
        store: Store(initialState: sampleState()) {
            AppReducer()
        } withDependencies: {
            $0.transmissionClient = .testValue
        }
    )
}

@MainActor
private func sampleState() -> AppReducer.State {
    var state: AppReducer.State = .init()
    state.serverList.servers = [
        ServerConfig.previewLocalHTTP,
        ServerConfig.previewSecureSeedbox
    ]
    return state
}
