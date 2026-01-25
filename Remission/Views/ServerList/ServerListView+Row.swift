import ComposableArchitecture
import SwiftUI

extension ServerListView {
    @ViewBuilder
    func serverRow(
        _ server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
        #if os(iOS)
            serverRowIOS(server)
        #else
            serverRowMac(server, status: status)
        #endif
    }

    private func serverRowIOS(_ server: ServerConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    store.send(.serverTapped(server.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(server.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(server.displayAddress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")

                HStack(spacing: 8) {
                    editButton(for: server)
                    deleteButton(for: server)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appCardSurface(cornerRadius: 14)
    }

    private func serverRowMac(
        _ server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                serverRowMacWide(server, status: status)
                serverRowMacCompact(server, status: status)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appCardSurface(cornerRadius: 14)
    }

    private func serverRowMacWide(
        _ server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                store.send(.serverTapped(server.id))
            } label: {
                serverRowInfoStack(for: server, status: status)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")

            HStack(spacing: 10) {
                storageSummaryChip(for: server, status: status)
                connectionStatusChip(status: status)
                securityBadge(for: server)
                editButton(for: server)
                deleteButton(for: server)
            }
        }
    }

    private func serverRowMacCompact(
        _ server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                store.send(.serverTapped(server.id))
            } label: {
                serverRowInfoStack(for: server, status: status)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("server_list_item_compact_\(server.id.uuidString)")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    storageSummaryChip(for: server, status: status)
                    connectionStatusChip(status: status)
                    securityBadge(for: server)
                    Spacer()
                    editButton(for: server)
                    deleteButton(for: server)
                }
            }
        }
    }

    private func serverRowInfoStack(
        for server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
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
            versionSummary(for: server, status: status)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func securityBadge(for server: ServerConfig) -> some View {
        if server.isSecure {
            badgeLabel(
                text: L10n.tr("serverList.badge.https"),
                systemImage: "lock.shield.fill",
                fill: .blue.opacity(0.12),
                foreground: .blue
            )
            .accessibilityLabel(L10n.tr("serverList.accessibility.secure"))
        } else {
            badgeLabel(
                text: L10n.tr("serverList.badge.http"),
                systemImage: "globe",
                fill: .orange.opacity(0.12),
                foreground: .orange
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
                        .fill(.secondary.opacity(0.12))
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
                        .fill(.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(L10n.tr("serverList.action.edit"))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func connectionStatusChip(
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
        let descriptor = ConnectionStatusChipDescriptor(phase: status.phase)

        Label(descriptor.label, systemImage: descriptor.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .background(Capsule().fill(descriptor.tint.opacity(0.15)))
            .foregroundStyle(descriptor.tint)
    }

    @ViewBuilder
    private func storageSummaryChip(
        for server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
        let summary = status.storageSummary
        if let summary {
            let total = StorageFormatters.bytes(summary.totalBytes)
            let free = StorageFormatters.bytes(summary.freeBytes)
            Label(
                String(format: L10n.tr("storage.summary.short"), total, free),
                systemImage: "externaldrive.fill"
            )
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .background(Capsule().fill(.secondary.opacity(0.12)))
            .foregroundStyle(.primary)
            .accessibilityIdentifier("server_list_storage_summary_\(server.id.uuidString)")
        }
    }

    @ViewBuilder
    private func versionSummary(
        for server: ServerConfig,
        status: ServerListReducer.ConnectionStatus
    ) -> some View {
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

struct ConnectionStatusChipDescriptor {
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
