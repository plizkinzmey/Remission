import SwiftUI

struct TorrentRowView: View, Equatable {
    var item: TorrentListItem.State
    var openRequested: (() -> Void)?
    var actions: RowActions?
    var longestStatusTitle: String
    var isLocked: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let metrics = item.metrics
        let status = statusData

        return VStack(alignment: .leading, spacing: 6) {
            headerRow(status: status)

            ProgressView(value: metrics.progressFraction)
                .tint(status.color)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")
                .accessibilityValue(metrics.progressText)

            #if os(iOS)
                iOSMetricsRow(metrics: metrics)
            #else
                macOSMetricsRow(metrics: metrics)
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            && lhs.longestStatusTitle == rhs.longestStatusTitle
            && lhsActions?.isActive == rhsActions?.isActive
            && lhsActions?.isLocked == rhsActions?.isLocked
            && lhsActions?.isStartPauseBusy == rhsActions?.isStartPauseBusy
            && lhsActions?.isVerifyBusy == rhsActions?.isVerifyBusy
            && lhsActions?.isRemoveBusy == rhsActions?.isRemoveBusy
    }
}

// MARK: - Subviews
extension TorrentRowView {
    private func headerRow(status: TorrentStatusData) -> some View {
        let category = TorrentCategory.category(from: item.torrent.tags)

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            categoryBadge(category)
                // `Image` has no baseline; align its bottom roughly with the title baseline.
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    // Move the badge slightly down so it visually aligns with the title's first line.
                    dimensions[.bottom] - 4
                }

            nameLabel
                .layoutPriority(1)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                #if os(macOS)
                    if let actions {
                        actionsPill(actions)
                    }
                #endif
                statusBadge(status: status)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }

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

    private func iOSMetricsRow(metrics: TorrentListItem.Metrics) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Label(metrics.peersText, systemImage: "person.2")
                .appCaption()
                .foregroundStyle(.primary)

            Text(metrics.ratioTextShort)
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .accessibilityIdentifier("torrent_row_ratio_\(item.torrent.id.rawValue)")

            Spacer(minLength: 6)

            Label(metrics.speedSummary, systemImage: "speedometer")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
        }
    }

    private func macOSMetricsRow(metrics: TorrentListItem.Metrics) -> some View {
        ViewThatFits(in: .horizontal) {
            wideMetricsRow(metrics: metrics)
            compactMetricsRow(metrics: metrics)
        }
    }

    private func wideMetricsRow(metrics: TorrentListItem.Metrics) -> some View {
        HStack(spacing: 12) {
            Label(metrics.progressText, systemImage: "circle.dashed")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .accessibilityIdentifier("torrent_row_progress_\(item.torrent.id.rawValue)")

            if let etaText = metrics.etaText {
                Label(etaText, systemImage: "clock")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
            }

            Label(metrics.peersText, systemImage: "person.2")
                .appCaption()
                .foregroundStyle(.primary)

            Label(metrics.ratioText, systemImage: "gauge.with.dots.needle.100percent")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .accessibilityIdentifier("torrent_row_ratio_\(item.torrent.id.rawValue)")

            Spacer(minLength: 6)

            Label(metrics.speedSummary, systemImage: "speedometer")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
        }
    }

    private func compactMetricsRow(metrics: TorrentListItem.Metrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Label(metrics.progressText, systemImage: "circle.dashed")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
                    .accessibilityIdentifier(
                        "torrent_row_progress_compact_\(item.torrent.id.rawValue)")

                if let etaText = metrics.etaText {
                    Label(etaText, systemImage: "clock")
                        .appCaption()
                        .foregroundStyle(.primary)
                        .appMonospacedDigit()
                }

                Label(metrics.peersText, systemImage: "person.2")
                    .appCaption()
                    .foregroundStyle(.primary)

                Label(metrics.ratioText, systemImage: "gauge.with.dots.needle.100percent")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
                    .accessibilityIdentifier(
                        "torrent_row_ratio_compact_\(item.torrent.id.rawValue)")
            }

            HStack(spacing: 12) {
                Spacer(minLength: 0)

                Label(metrics.speedSummary, systemImage: "speedometer")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
                    .lineLimit(1)
                    .accessibilityIdentifier(
                        "torrent_row_speed_compact_\(item.torrent.id.rawValue)")
            }
        }
    }

    private func actionsPill(_ actions: RowActions) -> some View {
        HStack(spacing: 10) {
            AppTorrentActionButton(
                type: actions.isActive ? .pause : .start,
                isBusy: actions.isStartPauseBusy,
                isLocked: actions.isLocked,
                action: actions.onStartPause
            )

            Divider()
                .frame(height: 18)

            AppTorrentActionButton(
                type: .verify,
                isBusy: actions.isVerifyBusy,
                isLocked: actions.isLocked,
                action: actions.onVerify
            )

            Divider()
                .frame(height: 18)

            AppTorrentActionButton(
                type: .remove,
                isBusy: actions.isRemoveBusy,
                isLocked: actions.isLocked,
                action: actions.onRemove
            )
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .appInteractivePillSurface()
        .appMaterialize()
        .accessibilityIdentifier("torrent_row_actions_\(item.id.rawValue)")
    }
}

// MARK: - Computed Properties
extension TorrentRowView {
    private var statusData: TorrentStatusData {
        TorrentStatusData(status: item.torrent.status)
    }

    private func categoryBadge(_ category: TorrentCategory) -> some View {
        let color = category.tintColor
        return ZStack {
            Image(systemName: category.systemImageName)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 22, height: 22)
        .background(.secondary.opacity(0.12), in: Circle())
        .overlay(Circle().strokeBorder(.quaternary))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("torrent_row_category_\(item.torrent.id.rawValue)")
        .accessibilityLabel(category.title)
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

    private func statusBadge(status: TorrentStatusData) -> some View {
        ZStack {
            Text(status.abbreviation)
                .font(.subheadline.weight(.semibold))
        }
        .frame(width: 28, height: 28)
        .background(status.color.opacity(0.15), in: Circle())
        .overlay(Circle().strokeBorder(status.color.opacity(0.25)))
        .foregroundStyle(status.color)
        .accessibilityIdentifier("torrent_list_item_status_\(item.id.rawValue)")
        .accessibilityLabel(status.title)
    }
}

// MARK: - Status Data Helper
private struct TorrentStatusData {
    let title: String
    let abbreviation: String
    let color: Color

    init(status: Torrent.Status) {
        switch status {
        case .stopped:
            title = L10n.tr("torrentList.status.paused")
            abbreviation = L10n.tr("torrentList.status.abbrev.paused")
            color = .secondary
        case .checkWaiting:
            title = L10n.tr("torrentList.status.checkWaiting")
            abbreviation = L10n.tr("torrentList.status.abbrev.checking")
            color = .orange
        case .checking:
            title = L10n.tr("torrentList.status.checking")
            abbreviation = L10n.tr("torrentList.status.abbrev.checking")
            color = .orange
        case .downloadWaiting:
            title = L10n.tr("torrentList.status.downloadWaiting")
            abbreviation = L10n.tr("torrentList.status.abbrev.waiting")
            color = .indigo
        case .downloading:
            title = L10n.tr("torrentList.status.downloading")
            abbreviation = L10n.tr("torrentList.status.abbrev.downloading")
            color = .blue
        case .seedWaiting:
            title = L10n.tr("torrentList.status.seedWaiting")
            abbreviation = L10n.tr("torrentList.status.abbrev.waiting")
            color = .indigo
        case .seeding:
            title = L10n.tr("torrentList.status.seeding")
            abbreviation = L10n.tr("torrentList.status.abbrev.seeding")
            color = .green
        case .isolated:
            title = L10n.tr("torrentList.status.error")
            abbreviation = L10n.tr("torrentList.status.abbrev.error")
            color = .red
        }
    }
}
