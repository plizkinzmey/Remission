import SwiftUI

struct TorrentRowView: View {
    var item: TorrentListItem.State
    var openRequested: (() -> Void)?
    var actions: RowActions?
    var longestStatusTitle: String
    var isLocked: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerRow

            #if os(iOS)
                if item.torrent.tags.isEmpty == false {
                    tagsRow
                }
            #endif

            ProgressView(value: item.metrics.progressFraction)
                .tint(statusData.color)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")
                .accessibilityValue(item.metrics.progressText)

            #if os(iOS)
                iOSMetricsRow
            #else
                macOSMetricsRow
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("torrent_row_\(item.torrent.id.rawValue)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
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
}

// MARK: - Subviews
extension TorrentRowView {
    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            nameLabel
                .layoutPriority(1)

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                #if os(macOS)
                    if let actions {
                        actionsPill(actions)
                    }
                #endif
                statusBadge
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

    private var iOSMetricsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Label(peersText, systemImage: "person.2")
                .appCaption()
                .foregroundStyle(.primary)

            Text(ratioTextShort)
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .accessibilityIdentifier("torrent_row_ratio_\(item.torrent.id.rawValue)")

            Spacer(minLength: 6)

            Label(item.metrics.speedSummary, systemImage: "speedometer")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
        }
    }

    private var macOSMetricsRow: some View {
        ViewThatFits(in: .horizontal) {
            wideMetricsRow
            compactMetricsRow
        }
    }

    private var wideMetricsRow: some View {
        HStack(spacing: 12) {
            Label(item.metrics.progressText, systemImage: "circle.dashed")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .accessibilityIdentifier("torrent_row_progress_\(item.torrent.id.rawValue)")

            if let etaText = item.metrics.etaText {
                Label(etaText, systemImage: "clock")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
            }

            Label(peersText, systemImage: "person.2")
                .appCaption()
                .foregroundStyle(.primary)

            Label(ratioText, systemImage: "gauge.with.dots.needle.100percent")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .accessibilityIdentifier("torrent_row_ratio_\(item.torrent.id.rawValue)")

            if item.torrent.tags.isEmpty == false {
                tagsInlineRow
                    .layoutPriority(0)
            }

            Spacer(minLength: 6)

            Label(item.metrics.speedSummary, systemImage: "speedometer")
                .appCaption()
                .foregroundStyle(.primary)
                .appMonospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
                .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
        }
    }

    private var compactMetricsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Label(item.metrics.progressText, systemImage: "circle.dashed")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
                    .accessibilityIdentifier(
                        "torrent_row_progress_compact_\(item.torrent.id.rawValue)")

                if let etaText = item.metrics.etaText {
                    Label(etaText, systemImage: "clock")
                        .appCaption()
                        .foregroundStyle(.primary)
                        .appMonospacedDigit()
                }

                Label(peersText, systemImage: "person.2")
                    .appCaption()
                    .foregroundStyle(.primary)

                Label(ratioText, systemImage: "gauge.with.dots.needle.100percent")
                    .appCaption()
                    .foregroundStyle(.primary)
                    .appMonospacedDigit()
                    .accessibilityIdentifier(
                        "torrent_row_ratio_compact_\(item.torrent.id.rawValue)")
            }

            HStack(spacing: 12) {
                if item.torrent.tags.isEmpty == false {
                    tagsInlineRow
                }

                Spacer(minLength: 0)

                Label(item.metrics.speedSummary, systemImage: "speedometer")
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
        .appPillSurface()
        .appMaterialize()
        .accessibilityIdentifier("torrent_row_actions_\(item.id.rawValue)")
    }

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 6) {
                ForEach(item.torrent.tags, id: \.self) { tag in
                    AppTagView(text: displayTagLabel(tag))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("torrent_row_tags_\(item.torrent.id.rawValue)")
    }

    private var tagsInlineRow: some View {
        let maxInlineTags = 3
        let tags = Array(item.torrent.tags.prefix(maxInlineTags))
        let remaining = item.torrent.tags.count - tags.count

        return HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                AppTagView(text: displayTagLabel(tag))
            }
            if remaining > 0 {
                AppTagView(text: "+\(remaining)")
            }
        }
        .accessibilityIdentifier("torrent_row_tags_inline_\(item.torrent.id.rawValue)")
    }
}

// MARK: - Computed Properties
extension TorrentRowView {
    private var statusData: TorrentStatusData {
        TorrentStatusData(status: item.torrent.status)
    }

    private var peersText: String {
        String(format: L10n.tr("torrentList.peers"), Int64(item.torrent.summary.peers.connected))
    }

    private var ratioText: String {
        String(
            format: L10n.tr("torrentList.ratio"),
            locale: Locale.current,
            item.torrent.summary.progress.uploadRatio
        )
    }

    private var ratioTextShort: String {
        String(
            format: L10n.tr("torrentList.ratio.short"),
            locale: Locale.current,
            item.torrent.summary.progress.uploadRatio
        )
    }

    private var accessibilityLabelText: String {
        String(
            format: L10n.tr("%@, %@, %@, %@"),
            locale: Locale.current,
            item.torrent.name,
            statusData.title,
            item.metrics.progressText,
            item.metrics.speedSummary
        )
    }

    private var statusBadge: some View {
        ZStack {
            Text(statusData.abbreviation)
                .font(.subheadline.weight(.semibold))
        }
        .frame(width: 28, height: 28)
        .background(statusData.color.opacity(0.15), in: Circle())
        .glassEffect(.regular, in: Circle())
        .overlay(Circle().strokeBorder(statusData.color.opacity(0.25)))
        .foregroundStyle(statusData.color)
        .accessibilityIdentifier("torrent_list_item_status_\(item.id.rawValue)")
        .accessibilityLabel(statusData.title)
    }

    private func displayTagLabel(_ tag: String) -> String {
        TorrentCategory.localizedTitle(for: tag) ?? tag
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
