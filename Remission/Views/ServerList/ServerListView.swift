import ComposableArchitecture
import Dependencies
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
        .confirmationDialog(
            $store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation)
        )
        .sheet(
            store: store.scope(state: \.$onboarding, action: \.onboarding)
        ) { onboardingStore in
            OnboardingView(store: onboardingStore)
        }
    }

    private var serverList: some View {
        List {
            ForEach(store.servers) { server in
                Button {
                    store.send(.serverTapped(server.id))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name)
                                .font(.headline)
                            Text(server.displayAddress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        securityBadge(for: server)
                    }
                }
                .accessibilityLabel(server.name)
                .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")
                #if os(iOS)
                    .swipeActions(edge: .trailing) {
                        Button("Удалить", role: .destructive) {
                            store.send(.deleteButtonTapped(server.id))
                        }
                        Button("Изменить") {
                            store.send(.editButtonTapped(server.id))
                        }
                        .tint(.blue)
                    }
                #endif
                #if os(macOS)
                    .contextMenu {
                        Button("Изменить") {
                            store.send(.editButtonTapped(server.id))
                        }
                        Button("Удалить", role: .destructive) {
                            store.send(.deleteButtonTapped(server.id))
                        }
                    }
                #endif
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
                .accessibilityIdentifier("server_list_empty_title")
            Text("Добавьте Transmission сервер, чтобы управлять торрентами.")
                .font(.body)
                .foregroundStyle(.secondary)
            Button {
                store.send(.addButtonTapped)
            } label: {
                Label("Добавить сервер", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("server_list_add_button")
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

    private func securityBadge(for server: ServerConfig) -> some View {
        Group {
            if server.isSecure {
                Label("HTTPS", systemImage: "lock.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                    )
                    .foregroundStyle(.green)
                    .accessibilityLabel("Безопасный сервер")
            } else {
                Label("HTTP", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.2))
                    )
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Небезопасный сервер")
            }
        }
    }
}

#Preview("Empty") {
    ServerListView(
        store: Store(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
            $0.credentialsRepository = .previewMock()
            $0.transmissionClient = .previewMock()
        }
    )
}

#Preview("With Servers") {
    var state: ServerListReducer.State = .init()
    state.servers = [
        ServerConfig.previewLocalHTTP,
        ServerConfig.previewSecureSeedbox
    ]
    return ServerListView(
        store: Store(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
            $0.credentialsRepository = .previewMock()
            $0.transmissionClient = .previewMock()
        }
    )
}
