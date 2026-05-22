import SwiftUI

struct ServerRowView: View, Equatable {
    let server: ServerConfig
    let status: ServerListReducer.ConnectionStatus
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showsConnectionInfo = false

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
    private var statusBorderStyle: AnyShapeStyle {
        switch status.phase {
        case .connected:
            return ServerRowColorTokens.connectedBorder
        case .failed:
            return ServerRowColorTokens.errorBorder
        case .idle, .probing:
            return ServerRowColorTokens.neutralBorder
        }
    }

    private var cardBackgroundStyle: AnyShapeStyle {
        #if os(iOS)
            return ServerRowColorTokens.cardBackground
        #else
            return ServerRowColorTokens.clear
        #endif
    }

    private var connectionInfoDescriptor: ServerConnectionInfoDescriptor? {
        guard case .connected(let handshake) = status.phase else {
            return nil
        }
        return ServerConnectionInfoDescriptor(server: server, handshake: handshake)
    }

    fileprivate var serverRowIOS: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                connectionStatusIcon
                connectionInfoButton

                Button(action: onTap) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Storage Summary & Actions Row
            HStack(alignment: .center) {
                if status.storageSummary != nil {
                    storageSummaryLabel
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
                .fill(cardBackgroundStyle)
                .shadow(color: ServerRowColorTokens.cardShadow, radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusBorderStyle, lineWidth: 1.5)
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
            serverRowInfoStack
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                storageSummaryLabel
                editButton
                deleteButton
            }
        }
    }

    fileprivate var serverRowMacCompact: some View {
        VStack(alignment: .leading, spacing: 12) {
            serverRowInfoStack
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    storageSummaryLabel
                    Spacer()
                    editButton
                    deleteButton
                }
            }
        }
    }

    fileprivate var serverRowInfoStack: some View {
        HStack(spacing: 6) {
            connectionStatusIcon
            connectionInfoButton
            Button(action: onTap) {
                HStack(spacing: 6) {
                    serverIdentityText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("server_list_item_\(server.id.uuidString)")
        }
    }

    fileprivate var serverIdentityText: some View {
        Group {
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
    }

    fileprivate var connectionInfoButton: some View {
        Button {
            showsConnectionInfo.toggle()
        } label: {
            Label(ServerListStrings.connectionInfo, systemImage: "info.circle")
        }
        .serverRowCircularIconButton()
        .tint(.secondary)
        .help(connectionInfoDescriptor?.helpText ?? server.displayAddress)
        .accessibilityLabel(ServerListStrings.connectionInfo)
        .accessibilityValue(connectionInfoDescriptor?.helpText ?? server.displayAddress)
        .popover(isPresented: $showsConnectionInfo) {
            connectionInfoPopover
        }
    }

    fileprivate var connectionInfoPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let descriptor = connectionInfoDescriptor {
                Text(descriptor.helpText)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
            } else {
                Text(server.displayAddress)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
        .padding(12)
        .frame(minWidth: 180, alignment: .leading)
    }

    fileprivate var deleteButton: some View {
        Button(action: onDelete) {
            Label(ServerListStrings.actionDelete, systemImage: "trash")
        }
        .serverRowCircularIconButton()
        .tint(.red)
        .accessibilityLabel(ServerListStrings.actionDelete)
    }

    fileprivate var editButton: some View {
        Button(action: onEdit) {
            Label(ServerListStrings.actionEdit, systemImage: "pencil")
        }
        .serverRowCircularIconButton()
        .tint(.secondary)
        .accessibilityLabel(ServerListStrings.actionEdit)
    }

    fileprivate var connectionStatusIcon: some View {
        let descriptor = ConnectionStatusChipDescriptor(phase: status.phase)

        return Image(systemName: descriptor.systemImage)
            .font(.body)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(descriptor.tint)
            .frame(width: 20, height: 20)
            .help(descriptor.label)
            .accessibilityLabel(descriptor.label)
    }

    @ViewBuilder
    fileprivate var storageSummaryLabel: some View {
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
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("server_list_storage_summary_\(server.id.uuidString)")
        } else {
            EmptyView()
        }
    }

}

private struct ServerRowCircularIconButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
    }
}

extension View {
    fileprivate func serverRowCircularIconButton() -> some View {
        modifier(ServerRowCircularIconButtonModifier())
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
            tint = ServerRowColorTokens.progress
        case .connected:
            label = ServerListStrings.statusConnected
            systemImage = "checkmark.circle.fill"
            tint = ServerRowColorTokens.connected
        case .failed:
            label = ServerListStrings.statusError
            systemImage = "exclamationmark.triangle.fill"
            tint = ServerRowColorTokens.error
        }
    }
}

struct ServerConnectionInfoDescriptor: Equatable {
    let transport: String
    let helpText: String

    init(server: ServerConfig, handshake: TransmissionHandshakeResult) {
        transport = server.isSecure ? "HTTPS" : "HTTP"

        let version: String
        if let versionDescription = handshake.serverVersionDescription,
            versionDescription.isEmpty == false
        {
            version = versionDescription
        } else {
            version = ServerListStrings.transmissionVersionUnavailable
        }
        let rpcText = String(
            format: ServerListStrings.rpcVersionTemplate,
            Int64(handshake.rpcVersion)
        )

        helpText = [
            version,
            rpcText,
            handshake.protocolSummaryText,
            transport
        ].joined(separator: "\n")
    }
}

enum ServerRowColorTokens {
    static let clear = AnyShapeStyle(Color.clear)
    static let cardBackground = AnyShapeStyle(.background.secondary)
    static let cardShadow = Color.primary.opacity(0.05)
    static let neutralBorder = AnyShapeStyle(.separator.opacity(0.35))
    static let connectedBorder = AnyShapeStyle(.green.opacity(0.35))
    static let errorBorder = AnyShapeStyle(.red.opacity(0.35))
    static let progress = Color.blue
    static let connected = Color.green
    static let error = Color.red
    static let infoIcon = AnyShapeStyle(.secondary)
}

enum ServerListStrings {
    static let serversTitle = L10n.tr("Servers")
    static let serversSubtitle =
        L10n.tr("Manage connections, security and actions for each Transmission server.")
    static let emptyTitle = L10n.tr("serverList.empty.title")
    static let emptyMessage = L10n.tr("serverList.empty.message")
    static let addServer = L10n.tr("serverList.action.addServer")
    static let actionDelete = L10n.tr("serverDetail.action.delete")
    static let actionEdit = L10n.tr("serverList.action.edit")
    static let statusConnecting = L10n.tr("serverDetail.status.connecting")
    static let statusConnected = L10n.tr("serverDetail.status.connected")
    static let statusError = L10n.tr("serverDetail.status.error")
    static let transmissionVersionUnavailable = L10n.tr("serverList.transmissionVersionUnavailable")
    static let connectionInfo = L10n.tr("serverList.connectionInfo")
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
