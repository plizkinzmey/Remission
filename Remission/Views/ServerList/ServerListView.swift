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
                VStack(alignment: .center, spacing: 12) {
                    Text(L10n.tr("Servers"))
                        .font(.title3.bold())
                    Text(
                        L10n.tr(
                            "Manage connections, security and actions for each Transmission server."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    serverList
                }
                .frame(maxWidth: .infinity)
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
                .appRootChrome()
        }
        .sheet(
            store: store.scope(state: \.$editor, action: \.editor)
        ) { editorStore in
            ServerEditorView(store: editorStore)
                .appRootChrome()
        }
    }

    private var serverList: some View {
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
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        #endif
    }

    private var serverRows: some View {
        ForEach(store.servers) { server in
            serverRow(server)
                .task {
                    await store.send(.connectionProbeRequested(server.id)).finish()
                }
                .accessibilityLabel(server.name)
                #if os(iOS)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 8, leading: 0, bottom: 12, trailing: 0))
                    .swipeActions(edge: .trailing) {
                        Button(L10n.tr("serverList.action.delete"), role: .destructive) {
                            store.send(.deleteButtonTapped(server.id))
                        }
                        Button(L10n.tr("serverList.action.edit")) {
                            store.send(.editButtonTapped(server.id))
                        }
                        .tint(.blue)
                    }
                #endif
        }
    }

    private func serverRow(_ server: ServerConfig) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Button {
                    store.send(.serverTapped(server.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(server.name)
                                .font(.headline)
                            Text(verbatim: "-")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text(server.displayAddress)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.9)
                        }
                        versionSummary(for: server)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")

                HStack(spacing: 10) {
                    storageSummaryChip(for: server)
                    connectionStatusChip(for: server)
                    securityBadge(for: server)
                    editButton(for: server)
                    deleteButton(for: server)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appCardSurface(cornerRadius: 14)
    }

    private var emptyState: some View {
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

    private func securityBadge(for server: ServerConfig) -> some View {
        if server.isSecure {
            badgeLabel(
                text: L10n.tr("serverList.badge.https"),
                systemImage: "lock.shield.fill",
                fill: Color.blue.opacity(0.18),
                foreground: Color.blue
            )
            .accessibilityLabel(L10n.tr("serverList.accessibility.secure"))
        } else {
            badgeLabel(
                text: L10n.tr("serverList.badge.http"),
                systemImage: "globe",
                fill: Color.orange.opacity(0.18),
                foreground: Color.orange
            )
            .accessibilityLabel(L10n.tr("serverList.accessibility.insecure"))
        }
    }

    private func deleteButton(for server: ServerConfig) -> some View {
        Button {
            store.send(.deleteButtonTapped(server.id))
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(height: macOSToolbarPillHeight)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(L10n.tr("serverDetail.action.delete"))
        .contentShape(Rectangle())
    }

    private func editButton(for server: ServerConfig) -> some View {
        Button {
            store.send(.editButtonTapped(server.id))
        } label: {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(height: macOSToolbarPillHeight)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(L10n.tr("serverList.action.edit"))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func connectionStatusChip(for server: ServerConfig) -> some View {
        let status = store.connectionStatuses[server.id] ?? .init()
        let descriptor = ConnectionStatusChipDescriptor(phase: status.phase)

        Label(descriptor.label, systemImage: descriptor.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .background(Capsule().fill(descriptor.tint.opacity(0.15)))
            .foregroundStyle(descriptor.tint)
    }

    @ViewBuilder
    private func storageSummaryChip(for server: ServerConfig) -> some View {
        let summary = store.connectionStatuses[server.id]?.storageSummary
        if let summary {
            let total = StorageFormatters.bytes(summary.totalBytes)
            let free = StorageFormatters.bytes(summary.freeBytes)
            Label(
                String(format: L10n.tr("storage.summary.short"), total, free),
                systemImage: "externaldrive.fill"
            )
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .foregroundStyle(.primary)
            .accessibilityIdentifier("server_list_storage_summary_\(server.id.uuidString)")
        }
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
                    .foregroundStyle(.primary)
            } else {
                HStack(spacing: 6) {
                    Text(L10n.tr("serverList.transmissionVersionLabel"))
                    Text(description)
                    Text(rpcText)
                }
                .font(.footnote)
                .foregroundStyle(.primary)
            }
        case .failed(let message):
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)
        default:
            EmptyView()
        }
    }

    private func badgeLabel(
        text: String,
        systemImage: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .background(
                Capsule()
                    .fill(fill)
            )
            .foregroundStyle(foreground)
    }

    private var macOSToolbarPillHeight: CGFloat { 34 }

}

private struct ConnectionStatusChipDescriptor {
    let label: String
    let systemImage: String
    let tint: Color

    init(phase: ServerListReducer.ConnectionStatusPhase) {
        switch phase {
        case .idle, .probing:
            label = L10n.tr("serverDetail.status.connecting")
            systemImage = "arrow.clockwise"
            tint = .blue
        case .connected:
            label = L10n.tr("serverDetail.status.connected")
            systemImage = "checkmark.circle.fill"
            tint = .green
        case .failed:
            label = L10n.tr("serverDetail.status.error")
            systemImage = "exclamationmark.triangle.fill"
            tint = .red
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
