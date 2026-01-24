import SwiftUI

struct DiagnosticsLevelBadge: View {
    let level: AppLogLevel

    var body: some View {
        Text(diagnosticsLevelLabel(level).uppercased())
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(diagnosticsLevelColor(level).opacity(0.15))
            .foregroundStyle(diagnosticsLevelColor(level))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("diagnostics_level_badge_\(level.rawValue)")
    }

    private func diagnosticsLevelLabel(_ level: AppLogLevel) -> String {
        switch level {
        case .debug: return L10n.tr("diagnostics.level.debug")
        case .info: return L10n.tr("diagnostics.level.info")
        case .warning: return L10n.tr("diagnostics.level.warn")
        case .error: return L10n.tr("diagnostics.level.error")
        }
    }

    private func diagnosticsLevelColor(_ level: AppLogLevel) -> Color {
        switch level {
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct DiagnosticsNetworkBadge: View {
    let isOffline: Bool
    let isNetworkIssue: Bool

    var body: some View {
        if isOffline || isNetworkIssue {
            let title =
                isOffline
                ? L10n.tr("diagnostics.offline.badge")
                : L10n.tr("diagnostics.network.badge")

            let imageName = isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
            let color: Color = isOffline ? .red : .orange

            Label(title, systemImage: imageName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(title)
                .accessibilityIdentifier(
                    isOffline ? "diagnostics_offline_badge" : "diagnostics_network_badge"
                )
                .overlay(
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.clear)
                        .accessibilityHidden(false)
                        .accessibilityIdentifier(
                            isOffline
                                ? "diagnostics_offline_badge_marker"
                                : "diagnostics_network_badge_marker"
                        )
                )
        }
    }
}
