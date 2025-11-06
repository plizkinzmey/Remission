import ComposableArchitecture
import SwiftUI

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>

    var body: some View {
        List {
            Section("Сервер") {
                LabeledContent("Название", value: store.server.name)
                LabeledContent("Адрес", value: store.server.displayAddress)
            }
        }
        .navigationTitle(store.server.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await store.send(.task).finish() }
    }
}

#Preview {
    ServerDetailView(
        store: Store(
            initialState: ServerDetailReducer.State(
                server: ServerConfig.previewLocalHTTP
            )
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    )
}
