import ComposableArchitecture
import SwiftUI

struct DiagnosticsLogRowView: View {

    let entry: DiagnosticsLogEntry
    let onCopy: () -> Void

    @State private var isDetailsPresented: Bool = false

    var body: some View {
        let metadata = DiagnosticsLogFormatter.metadataTags(for: entry)
        let errorSummary = DiagnosticsLogFormatter.errorSummary(for: entry)
        let isOffline = DiagnosticsLogFormatter.isOffline(entry)
        let isNetworkIssue = DiagnosticsLogFormatter.isNetworkIssue(entry)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    isDetailsPresented = true
                } label: {
                    DiagnosticsLevelBadge(level: entry.level)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(4)
                    Text(entry.category)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Text(diagnosticsTimeFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DiagnosticsNetworkBadge(isOffline: isOffline, isNetworkIssue: isNetworkIssue)

            if let errorSummary {
                Text(errorSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("diagnostics_error_summary_\(entry.id.uuidString)")
            }

            if metadata.isEmpty == false {
                metadataRow(metadata)
            }
        }
        .padding(.vertical, 2)
        .contextMenu { copyButton }
        #if os(iOS)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                copyButton
            }
        #endif
        .sheet(isPresented: $isDetailsPresented) {
            DiagnosticsLogDetailsSheet(entry: entry)
        }
        .accessibilityIdentifier("diagnostics_log_row_\(entry.id.uuidString)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .overlay(alignment: .topLeading) {
            accessibilityOverlay(isOffline: isOffline, isNetworkIssue: isNetworkIssue)
        }
    }

    private var copyButton: some View {
        Button {
            onCopy()
        } label: {
            Label(L10n.tr("diagnostics.copy"), systemImage: "doc.on.doc")
        }
        .tint(Color.accentColor)
        .accessibilityIdentifier("diagnostics_copy_\(entry.id.uuidString)")
    }
    private func metadataRow(_ metadata: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(metadata, id: \.self) { item in
                    metadataBadge(item)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func metadataBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.12))
            )
            .accessibilityLabel(text)
            .accessibilityIdentifier("diagnostics_metadata_\(text)")
    }

    private func accessibilityOverlay(isOffline: Bool, isNetworkIssue: Bool) -> some View {
        Group {
            if isOffline {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("diagnostics_offline_badge")
            } else if isNetworkIssue {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityIdentifier("diagnostics_network_badge")
            }
        }
    }

    private var accessibilityLabel: String {
        var label = String(
            format: L10n.tr("%@, %@: %@"),
            locale: Locale.current,
            diagnosticsTimeFormatter.string(from: entry.timestamp),
            diagnosticsLevelLabel(entry.level),
            entry.message
        )
        if DiagnosticsLogFormatter.isOffline(entry) {
            label.append(", \(L10n.tr("diagnostics.offline.badge"))")
        }
        return label
    }

    private func diagnosticsLevelLabel(_ level: AppLogLevel) -> String {
        switch level {
        case .debug: return L10n.tr("diagnostics.level.debug")
        case .info: return L10n.tr("diagnostics.level.info")
        case .warning: return L10n.tr("diagnostics.level.warn")
        case .error: return L10n.tr("diagnostics.level.error")
        }
    }

    private let diagnosticsTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
