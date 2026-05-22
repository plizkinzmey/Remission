import SwiftUI

struct TorrentRowView: View, Equatable {
    var item: TorrentListItem.State
    var openRequested: (() -> Void)?
    var actions: RowActions?
    var isLocked: Bool

    var body: some View {
        let metrics = item.metrics
        let status = statusData
        let category = TorrentCategory.category(from: item.torrent.tags)

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: category.systemImageName)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .accessibilityIdentifier("torrent_row_category_\(item.torrent.id.rawValue)")
                .accessibilityLabel(category.title)

            VStack(alignment: .leading, spacing: 6) {
                nameLabel

                ProgressView(value: metrics.progressFraction)
                    .tint(status.color)
                    .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")
                    .accessibilityValue(metrics.progressText)

                metricsRow(metrics: metrics)
            }
            .layoutPriority(1)

            trailingStatus(status)
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("torrent_row_\(item.torrent.id.rawValue)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText(status: status, metrics: metrics))
        #if !os(macOS)
            .accessibilityHint(L10n.tr("Open torrent details"))
        #endif
    }

    struct RowActions {
        var isActive: Bool
        var isLocked: Bool
        var isStartPauseBusy: Bool
        var isVerifyBusy: Bool
        var isRemoveBusy: Bool
        var onStartPause: () -> Void
        var onVerify: () -> Void
        var onRemove: () -> Void

        var isAnyBusy: Bool {
            isStartPauseBusy || isVerifyBusy || isRemoveBusy
        }
    }

    static func == (lhs: TorrentRowView, rhs: TorrentRowView) -> Bool {
        let lhsActions = lhs.actions
        let rhsActions = rhs.actions
        return lhs.item.displaySignature == rhs.item.displaySignature
            && lhs.isLocked == rhs.isLocked
            && lhsActions?.isActive == rhsActions?.isActive
            && lhsActions?.isLocked == rhsActions?.isLocked
            && lhsActions?.isStartPauseBusy == rhsActions?.isStartPauseBusy
            && lhsActions?.isVerifyBusy == rhsActions?.isVerifyBusy
            && lhsActions?.isRemoveBusy == rhsActions?.isRemoveBusy
    }
}

extension TorrentRowView {
    private var nameLabel: some View {
        Group {
            if let openRequested {
                Button(action: openRequested) {
                    Text(item.torrent.name)
                        .font(.headline)
                        .lineLimit(2)
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
                .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
            } else {
                Text(item.torrent.name)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityIdentifier("torrent_row_name_\(item.torrent.id.rawValue)")
            }
        }
    }

    private func metricsRow(metrics: TorrentListItem.Metrics) -> some View {
        #if os(macOS)
            wideMetricsRow(metrics: metrics)
        #else
            ViewThatFits(in: .horizontal) {
                wideMetricsRow(metrics: metrics)
                compactMetricsRow(metrics: metrics)
            }
        #endif
    }

    private func wideMetricsRow(metrics: TorrentListItem.Metrics) -> some View {
        HStack(spacing: 12) {
            Label(metrics.progressText, systemImage: "circle.dashed")
                .accessibilityIdentifier("torrent_row_progress_\(item.torrent.id.rawValue)")

            if let etaText = metrics.etaText {
                Label(etaText, systemImage: "clock")
            }

            Label(metrics.peersText, systemImage: "person.2")

            Label(metrics.ratioText, systemImage: "gauge.with.dots.needle.100percent")
                .accessibilityIdentifier("torrent_row_ratio_\(item.torrent.id.rawValue)")

            Spacer(minLength: 0)

            Label(metrics.speedSummary, systemImage: "speedometer")
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private func compactMetricsRow(metrics: TorrentListItem.Metrics) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 12) {
                Label(metrics.progressText, systemImage: "circle.dashed")
                    .accessibilityIdentifier(
                        "torrent_row_progress_compact_\(item.torrent.id.rawValue)")

                Label(metrics.peersText, systemImage: "person.2")

                Label(metrics.ratioTextShort, systemImage: "gauge.with.dots.needle.100percent")
                    .accessibilityIdentifier(
                        "torrent_row_ratio_compact_\(item.torrent.id.rawValue)")
            }

            HStack(spacing: 12) {
                if let etaText = metrics.etaText {
                    Label(etaText, systemImage: "clock")
                }

                Label(metrics.speedSummary, systemImage: "speedometer")
                    .lineLimit(1)
                    .accessibilityIdentifier(
                        "torrent_row_speed_compact_\(item.torrent.id.rawValue)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }

    private func trailingStatus(_ status: TorrentStatusData) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Label(status.title, systemImage: status.systemImage)
                .labelStyle(.iconOnly)
                .foregroundStyle(status.color)
                .accessibilityIdentifier("torrent_list_item_status_\(item.id.rawValue)")
                .accessibilityLabel(status.title)

            if let actions {
                Menu {
                    Button {
                        actions.onStartPause()
                    } label: {
                        Label(
                            actions.isActive
                                ? L10n.tr("torrentDetail.actions.pause")
                                : L10n.tr("torrentDetail.actions.start"),
                            systemImage: actions.isActive ? "pause.fill" : "play.fill"
                        )
                    }
                    .disabled(actions.isStartPauseBusy || actions.isLocked)

                    Button {
                        actions.onVerify()
                    } label: {
                        Label(L10n.tr("torrentDetail.actions.verify"), systemImage: "shield")
                    }
                    .disabled(actions.isVerifyBusy || actions.isLocked)

                    Button(role: .destructive) {
                        actions.onRemove()
                    } label: {
                        Label(L10n.tr("torrentDetail.actions.remove"), systemImage: "trash")
                    }
                    .disabled(actions.isRemoveBusy || actions.isLocked)
                } label: {
                    Label(
                        L10n.tr("torrentDetail.actions.removePrompt"),
                        systemImage: "ellipsis.circle"
                    )
                    .labelStyle(.iconOnly)
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(actions.isLocked)
                .accessibilityIdentifier("torrent_row_actions_\(item.id.rawValue)")
            }
        }
        .frame(minWidth: 32, alignment: .trailing)
    }

    private var statusData: TorrentStatusData {
        TorrentStatusData(status: item.torrent.status)
    }

    private func accessibilityLabelText(
        status: TorrentStatusData,
        metrics: TorrentListItem.Metrics
    ) -> String {
        String(
            format: L10n.tr("%@, %@, %@, %@"),
            locale: Locale.current,
            item.torrent.name,
            status.title,
            metrics.progressText,
            metrics.speedSummary
        )
    }
}

private struct TorrentStatusData {
    let title: String
    let systemImage: String
    let color: Color

    init(status: Torrent.Status) {
        switch status {
        case .stopped:
            title = L10n.tr("torrentList.status.paused")
            systemImage = "pause.circle"
            color = .secondary
        case .checkWaiting:
            title = L10n.tr("torrentList.status.checkWaiting")
            systemImage = "clock.badge.checkmark"
            color = .orange
        case .checking:
            title = L10n.tr("torrentList.status.checking")
            systemImage = "checkmark.circle"
            color = .orange
        case .downloadWaiting:
            title = L10n.tr("torrentList.status.downloadWaiting")
            systemImage = "clock.arrow.circlepath"
            color = .indigo
        case .downloading:
            title = L10n.tr("torrentList.status.downloading")
            systemImage = "arrow.down.circle"
            color = .blue
        case .seedWaiting:
            title = L10n.tr("torrentList.status.seedWaiting")
            systemImage = "clock.arrow.circlepath"
            color = .indigo
        case .seeding:
            title = L10n.tr("torrentList.status.seeding")
            systemImage = "arrow.up.circle"
            color = .green
        case .isolated:
            title = L10n.tr("torrentList.status.error")
            systemImage = "exclamationmark.triangle"
            color = .red
        }
    }
}
