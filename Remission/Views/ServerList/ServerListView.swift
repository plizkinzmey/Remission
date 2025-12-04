import ComposableArchitecture
import Dependencies
import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct ServerListView: View {
    @Bindable var store: StoreOf<ServerListReducer>
    @State private var popoverServerID: UUID?

    var body: some View {
        Group {
            if store.servers.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.tr("Servers"))
                        .font(.title3.bold())
                    Text(
                        L10n.tr(
                            "Manage connections, security and actions for each Transmission server."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    serverList
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
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
        #if os(macOS)
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.servers) { server in
                        serverRow(server)
                            .task {
                                await store.send(.connectionProbeRequested(server.id)).finish()
                            }
                            .accessibilityLabel(server.name)
                            .contextMenu {
                                Button(L10n.tr("serverList.action.edit")) {
                                    store.send(.editButtonTapped(server.id))
                                }
                                Button(L10n.tr("serverList.action.delete"), role: .destructive) {
                                    store.send(.deleteButtonTapped(server.id))
                                }
                            }
                    }
                }
                .padding(.top, 4)
            }
        #else
            List {
                ForEach(store.servers) { server in
                    serverRow(server)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 0, bottom: 12, trailing: 0))
                        .task {
                            await store.send(.connectionProbeRequested(server.id)).finish()
                        }
                        .accessibilityLabel(server.name)
                        .swipeActions(edge: .trailing) {
                            Button(L10n.tr("serverList.action.delete"), role: .destructive) {
                                store.send(.deleteButtonTapped(server.id))
                            }
                            Button(L10n.tr("serverList.action.edit")) {
                                store.send(.editButtonTapped(server.id))
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.insetGrouped)
        #endif
    }

    private func serverRow(_ server: ServerConfig) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.05))
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)

            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 16) {
                    Button {
                        store.send(.serverTapped(server.id))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name)
                                .font(.headline)
                            Text(server.displayAddress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")
                    .contentShape(Rectangle())

                    HStack(spacing: 10) {
                        connectionStatusChip(for: server)
                        securityBadge(for: server)
                        deleteButton(for: server)
                    }
                }

                versionSummary(for: server)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor).opacity(0.18)
        #else
            Color(.secondarySystemGroupedBackground)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(L10n.tr("serverList.empty.title"))
                .font(.title3)
                .accessibilityIdentifier("server_list_empty_title")
            Text(L10n.tr("serverList.empty.message"))
                .font(.body)
                .foregroundStyle(.secondary)
            Button {
                store.send(.addButtonTapped)
            } label: {
                Label(L10n.tr("serverList.action.addServer"), systemImage: "plus")
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
                badgeLabel(
                    text: L10n.tr("serverList.badge.https"),
                    systemImage: "lock.fill",
                    fill: Color.green.opacity(0.2),
                    foreground: Color.green
                )
                .accessibilityLabel(L10n.tr("serverList.accessibility.secure"))
                .help(L10n.tr("serverDetail.security.https"))
            } else {
                Button {
                    popoverServerID = server.id
                } label: {
                    badgeLabel(
                        text: L10n.tr("serverList.badge.http"),
                        systemImage: "exclamationmark.triangle.fill",
                        fill: Color.orange.opacity(0.25),
                        foreground: Color.orange
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("serverList.accessibility.insecure"))
                .popover(
                    isPresented: Binding(
                        get: { popoverServerID == server.id },
                        set: { newValue in
                            popoverServerID = newValue ? server.id : nil
                        }
                    ), attachmentAnchor: .point(.trailing)
                ) {
                    securityInfoPopover(for: server)
                }
            }
        }
    }

    private func deleteButton(for server: ServerConfig) -> some View {
        Button {
            store.send(.deleteButtonTapped(server.id))
        } label: {
            Image(systemName: "trash")
                .imageScale(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(L10n.tr("serverDetail.action.delete"))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func connectionStatusChip(for server: ServerConfig) -> some View {
        let status = store.connectionStatuses[server.id] ?? .init()
        let (label, systemImage, tint): (String, String, Color) = {
            switch status.phase {
            case .idle, .probing:
                return (L10n.tr("serverDetail.status.connecting"), "arrow.clockwise", .secondary)
            case .connected:
                return (L10n.tr("serverDetail.status.connected"), "checkmark.circle.fill", .green)
            case .failed:
                return (L10n.tr("serverDetail.status.error"), "exclamationmark.triangle.fill", .red)
            }
        }()

        Label(label, systemImage: systemImage)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.15)))
            .foregroundStyle(tint)
    }

    @ViewBuilder
    private func versionSummary(for server: ServerConfig) -> some View {
        let status = store.connectionStatuses[server.id] ?? .init()
        switch status.phase {
        case .connected(let handshake):
            let description = handshake.serverVersionDescription ?? ""
            let rpcText = String(
                format: L10n.tr("serverDetail.status.rpcVersion"),
                Int64(handshake.rpcVersion)
            )
            if description.isEmpty {
                Text(rpcText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    Text(description)
                    Text(rpcText)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func securityInfoPopover(for server: ServerConfig) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if server.isSecure {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.green)
                    Text(L10n.tr("serverDetail.security.https"))
                        .font(.headline)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L10n.tr("serverDetail.security.httpWarning"))
                        .font(.headline)
                }
                Spacer()
            }
            if server.isSecure == false {
                Text(L10n.tr("serverDetail.security.httpHint"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 240)
    }

    private func badgeLabel(
        text: String,
        systemImage: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(fill)
            )
            .foregroundStyle(foreground)
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
