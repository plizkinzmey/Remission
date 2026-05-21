import SwiftUI

struct ServerRowView: View, Equatable {
    let server: ServerConfig
    let status: ServerListReducer.ConnectionStatus
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var pulseScale: CGFloat = 1.0

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
    private var hasAdditionalInfo: Bool {
        switch status.phase {
        case .connected, .failed:
            return true
        default:
            return false
        }
    }

    private var statusBorderColor: Color {
        switch status.phase {
        case .connected:
            return .green.opacity(0.15)
        case .failed:
            return .red.opacity(0.15)
        case .idle, .probing:
            return .blue.opacity(0.1)
        }
    }

    private var cardBackgroundColor: Color {
        #if os(iOS)
            return Color(uiColor: .secondarySystemGroupedBackground)
        #else
            return Color.clear
        #endif
    }

    private var connectionStatusIndicator: some View {
        let tint = ConnectionStatusChipDescriptor(phase: status.phase).tint
        let isConnecting = status.phase == .idle || status.phase == .probing

        return ZStack {
            if isConnecting {
                Circle()
                    .stroke(tint.opacity(0.3), lineWidth: 3)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false))
                        {
                            pulseScale = 2.0
                        }
                    }
            }

            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)
                .shadow(color: tint.opacity(0.4), radius: 2)
        }
    }

    fileprivate var serverRowIOS: some View {
        VStack(spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header Row: Icon + Server Name + Security Badge
                    HStack(alignment: .center, spacing: 10) {
                        connectionStatusIndicator

                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(server.displayAddress)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        securityBadge
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Version Summary (only if connected or failed)
                    if hasAdditionalInfo {
                        Divider()
                            .background(Color.secondary.opacity(0.2))

                        versionSummary
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")

            // Storage Summary & Actions Row
            HStack(alignment: .center) {
                if status.storageSummary != nil {
                    storageSummaryChip
                } else {
                    connectionStatusChip
                }

                Spacer()

                HStack(spacing: 12) {
                    editButton
                    deleteButton
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusBorderColor, lineWidth: 1.5)
        )
    }

    fileprivate var serverRowMac: some View {
        GroupBox {
            VStack(spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    serverRowMacWide
                    serverRowMacCompact
                }
            }
        }
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
                fill: .blue.opacity(0.15),
                foreground: .blue
            )
            .accessibilityLabel(ServerListStrings.accessibilitySecure)
        } else {
            badgeLabel(
                text: ServerListStrings.badgeHTTP,
                systemImage: "globe",
                fill: .orange.opacity(0.15),
                foreground: .orange
            )
            .accessibilityLabel(ServerListStrings.accessibilityInsecure)
        }
    }

    fileprivate var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .accessibilityLabel(ServerListStrings.actionDelete)
    }

    fileprivate var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(ServerListStrings.actionEdit)
    }

    fileprivate var connectionStatusChip: some View {
        let descriptor = ConnectionStatusChipDescriptor(phase: status.phase)

        return Label(descriptor.label, systemImage: descriptor.systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(descriptor.tint.opacity(0.15), in: Capsule())
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
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
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
            let protocolText = handshake.protocolSummaryText
            if description.isEmpty {
                HStack(spacing: 6) {
                    Text(rpcText)
                    Text(protocolText)
                }
                .font(.footnote)
                .foregroundStyle(.primary)
            } else {
                HStack(spacing: 6) {
                    Text(ServerListStrings.transmissionVersionLabel)
                    Text(description)
                    Text(rpcText)
                    Text(protocolText)
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
            .padding(.vertical, 6)
            .background(fill, in: Capsule())
            .foregroundStyle(foreground)
    }
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

extension TransmissionHandshakeResult {
    fileprivate var protocolSummaryText: String {
        switch rpcMode {
        case .jsonRpc2:
            if let semver = rpcVersionSemver, semver.isEmpty == false {
                return "JSON-RPC 2.0 (\(semver))"
            }
            return "JSON-RPC 2.0"
        case .legacy:
            return "Legacy RPC"
        case .auto:
            return "RPC auto"
        }
    }
}
