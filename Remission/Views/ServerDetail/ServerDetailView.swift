import ComposableArchitecture
import SwiftUI

struct ServerDetailView: View {
    @Bindable var store: StoreOf<ServerDetailReducer>

    var body: some View {
        List {
            Section("Сервер") {
                LabeledContent("Название", value: store.server.name)
                LabeledContent("Адрес", value: store.server.address)
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
                server: .init(id: UUID(), name: "NAS", address: "http://nas.local:9091")
            )
        ) {
            ServerDetailReducer()
        }
    )
}
