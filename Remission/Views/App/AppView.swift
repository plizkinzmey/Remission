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
            $0 = AppDependencies.makePreview()
        }
    )
}

#Preview("AppView Sample") {
    AppView(
        store: Store(initialState: sampleState()) {
            AppReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    )
}

#Preview("AppView Legacy Migration") {
    AppView(
        store: Store(initialState: migratedLegacyState()) {
            AppReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
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

@MainActor
private func migratedLegacyState() -> AppReducer.State {
    var serverList = ServerListReducer.State()
    serverList.servers = [
        ServerConfig.previewLocalHTTP
    ]
    let legacyDetailState = ServerDetailReducer.State(server: .previewLocalHTTP)
    let legacyState = AppReducer.State(
        version: .legacy,
        serverList: serverList,
        path: StackState([legacyDetailState])
    )
    return AppBootstrap.makeInitialState(
        arguments: [],
        targetVersion: .latest,
        existingState: legacyState
    )
}
