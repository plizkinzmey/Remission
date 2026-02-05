import SwiftUI

struct ServerRowView: View, Equatable {
    let server: ServerConfig
    let status: ServerListReducer.ConnectionStatus
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        #if os(iOS)
            serverRowIOS
        #else
            serverRowMac
        #endif
    }

    static func == (lhs: ServerRowView, rhs: ServerRowView) -> Bool {
        lhs.server == rhs.server
            && lhs.status == rhs.status
    }
}

extension ServerRowView {
    fileprivate var serverRowIOS: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: onTap) {
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
                    editButton
                    deleteButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appTintedCardSurface(color: .accentColor, opacity: 0.05)
    }

    fileprivate var serverRowMac: some View {
        VStack(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                serverRowMacWide
                serverRowMacCompact
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .appTintedCardSurface(color: .accentColor, opacity: 0.05)
    }

    fileprivate var serverRowMacWide: some View {
        HStack(alignment: .center, spacing: 16) {
            Button(action: onTap) {
                serverRowInfoStack
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")

            HStack(spacing: 10) {
                storageSummaryChip
                connectionStatusChip
                securityBadge
                editButton
                deleteButton
            }
        }
    }

    fileprivate var serverRowMacCompact: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onTap) {
                serverRowInfoStack
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("server_list_item_compact_\(server.id.uuidString)")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    storageSummaryChip
                    connectionStatusChip
                    securityBadge
                    Spacer()
                    editButton
                    deleteButton
                }
            }
        }
    }

    fileprivate var serverRowInfoStack: some View {
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
            versionSummary
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    fileprivate var securityBadge: some View {
        if server.isSecure {
            badgeLabel(
                text: ServerListStrings.badgeHTTPS,
                systemImage: "lock.shield.fill",
                fill: .blue.opacity(0.12),
                foreground: .blue
            )
            .accessibilityLabel(ServerListStrings.accessibilitySecure)
        } else {
            badgeLabel(
                text: ServerListStrings.badgeHTTP,
                systemImage: "globe",
                fill: .orange.opacity(0.12),
                foreground: .orange
            )
            .accessibilityLabel(ServerListStrings.accessibilityInsecure)
        }
    }

    fileprivate var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(height: macOSToolbarPillHeight)
                .appInteractivePillSurface()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(ServerListStrings.actionDelete)
        .contentShape(Rectangle())
    }

    fileprivate var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 24, height: 24)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(height: macOSToolbarPillHeight)
                .appInteractivePillSurface()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(ServerListStrings.actionEdit)
        .contentShape(Rectangle())
    }

    fileprivate var connectionStatusChip: some View {
        let descriptor = ConnectionStatusChipDescriptor(phase: status.phase)

        return Label(descriptor.label, systemImage: descriptor.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .appTintedPillSurface(color: descriptor.tint)
            .foregroundStyle(descriptor.tint)
    }

    @ViewBuilder
    fileprivate var storageSummaryChip: some View {
        if let summary = status.storageSummary {
            let total = StorageFormatters.bytes(summary.totalBytes)
            let free = StorageFormatters.bytes(summary.freeBytes)
            Label(
                String(format: ServerListStrings.storageSummaryTemplate, total, free),
                systemImage: "externaldrive.fill"
            )
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .appPillSurface()
            .foregroundStyle(.primary)
            .accessibilityIdentifier("server_list_storage_summary_\(server.id.uuidString)")
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    fileprivate var versionSummary: some View {
        switch status.phase {
        case .connected(let handshake):
            let description = handshake.serverVersionDescription ?? ""
            let rpcText = String(
                format: ServerListStrings.rpcVersionTemplate,
                Int64(handshake.rpcVersion)
            )
            if description.isEmpty {
                Text(rpcText)
                    .font(.footnote)
                    .foregroundStyle(.primary)
            } else {
                HStack(spacing: 6) {
                    Text(ServerListStrings.transmissionVersionLabel)
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

    fileprivate func badgeLabel(
        text: String,
        systemImage: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: macOSToolbarPillHeight)
            .appTintedPillSurface(color: foreground)
            .foregroundStyle(foreground)
    }

    fileprivate var macOSToolbarPillHeight: CGFloat { 34 }
}

struct ConnectionStatusChipDescriptor {
    let label: String
    let systemImage: String
    let tint: Color

    init(phase: ServerListReducer.ConnectionStatusPhase) {
        switch phase {
        case .idle, .probing:
            label = ServerListStrings.statusConnecting
            systemImage = "arrow.clockwise"
            tint = .blue
        case .connected:
            label = ServerListStrings.statusConnected
            systemImage = "checkmark.circle.fill"
            tint = .green
        case .failed:
            label = ServerListStrings.statusError
            systemImage = "exclamationmark.triangle.fill"
            tint = .red
        }
    }
}

enum ServerListStrings {
    static let serversTitle = L10n.tr("Servers")
    static let serversSubtitle =
        L10n.tr("Manage connections, security and actions for each Transmission server.")
    static let emptyTitle = L10n.tr("serverList.empty.title")
    static let emptyMessage = L10n.tr("serverList.empty.message")
    static let addServer = L10n.tr("serverList.action.addServer")
    static let badgeHTTPS = L10n.tr("serverList.badge.https")
    static let badgeHTTP = L10n.tr("serverList.badge.http")
    static let accessibilitySecure = L10n.tr("serverList.accessibility.secure")
    static let accessibilityInsecure = L10n.tr("serverList.accessibility.insecure")
    static let actionDelete = L10n.tr("serverDetail.action.delete")
    static let actionEdit = L10n.tr("serverList.action.edit")
    static let statusConnecting = L10n.tr("serverDetail.status.connecting")
    static let statusConnected = L10n.tr("serverDetail.status.connected")
    static let statusError = L10n.tr("serverDetail.status.error")
    static let transmissionVersionLabel = L10n.tr("serverList.transmissionVersionLabel")
    static let rpcVersionTemplate = L10n.tr("serverDetail.status.rpcVersion")
    static let storageSummaryTemplate = L10n.tr("storage.summary.short")
}
