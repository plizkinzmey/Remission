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
                VStack(alignment: .center, spacing: 12) {
                    Text(L10n.tr("Servers"))
                        .font(.title3.bold())
                    Text(
                        L10n.tr(
                            "Manage connections, security and actions for each Transmission server."
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            .scrollContentBackground(.hidden)
        #endif
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
                                .foregroundStyle(.secondary)
                            Text(server.displayAddress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
                    connectionStatusChip(for: server)
                    securityBadge(for: server)
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
                Text(L10n.tr("serverList.action.addServer"))
            }
            .buttonStyle(EmptyStatePrimaryButtonStyle())
            .accessibilityIdentifier("server_list_add_button")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding()
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
        .foregroundStyle(.secondary)
        .accessibilityLabel(L10n.tr("serverDetail.action.delete"))
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
                    Text(L10n.tr("serverList.transmissionVersionLabel"))
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
            tint = .secondary
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

private struct EmptyStatePrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .frame(minHeight: 30)
            .foregroundStyle(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(accentFill.opacity(colorScheme == .dark ? 0.65 : 1.0))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
    }

    private var accentFill: Color {
        #if os(macOS)
            return Color(nsColor: .controlAccentColor)
        #else
            return AppTheme.accent
        #endif
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
