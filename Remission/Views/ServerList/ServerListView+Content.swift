import ComposableArchitecture
import SwiftUI

extension ServerListView {
    var serverList: some View {
        #if os(macOS)
            ScrollView {
                LazyVStack(spacing: 12) {
                    serverRows
                }
                .padding(.top, 4)
            }
            .scrollDisabled(store.servers.count <= 1)
        #else
            List {
                serverRows
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        #endif
    }

    var serverRows: some View {
        ForEach(store.servers) { server in
            serverRow(server)
                .task {
                    await store.send(.connectionProbeRequested(server.id)).finish()
                }
                .accessibilityLabel(server.name)
                #if os(iOS)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 8, bottom: 12, trailing: 8))
                    .listRowSeparator(.hidden)
                #endif
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.primary)
            Text(L10n.tr("serverList.empty.title"))
                .font(.title3)
                .accessibilityIdentifier("server_list_empty_title")
            Text(L10n.tr("serverList.empty.message"))
                .font(.body)
                .foregroundStyle(.primary)
            Button {
                store.send(.addButtonTapped)
            } label: {
                Text(L10n.tr("serverList.action.addServer"))
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .accessibilityIdentifier("server_list_add_button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding()
    }

    var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
