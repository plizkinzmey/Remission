import ComposableArchitecture
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct ServerListView: View {
    @Bindable var store: StoreOf<ServerListReducer>

    var body: some View {
        Group {
            if store.servers.isEmpty {
                emptyState
            } else {
                serverList
            }
        }
        .task { await store.send(.task).finish() }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
    }

    private var serverList: some View {
        List {
            ForEach(store.servers) { server in
                Button {
                    store.send(.serverTapped(server.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.headline)
                        Text(server.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onDelete { indexSet in
                store.send(.remove(indexSet))
            }
        }
        #if os(macOS)
            .listStyle(.automatic)
        #else
            .listStyle(.insetGrouped)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Нет подключённых серверов")
                .font(.title3)
            Text("Добавьте Transmission сервер, чтобы управлять торрентами.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button {
                store.send(.addButtonTapped)
            } label: {
                Label("Добавить сервер", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding()
        .background(emptyStateBackgroundColor)
    }

    private var emptyStateBackgroundColor: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #else
            Color(.systemGroupedBackground)
        #endif
    }
}

#Preview("Empty") {
    ServerListView(
        store: Store(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0.transmissionClient = .testValue
        }
    )
}

#Preview("With Servers") {
    var state: ServerListReducer.State = .init()
    state.servers = [
        .init(id: UUID(), name: "NAS", address: "http://nas.local:9091"),
        .init(id: UUID(), name: "Seedbox", address: "https://seedbox.example.com")
    ]
    return ServerListView(
        store: Store(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.transmissionClient = .testValue
        }
    )
}
