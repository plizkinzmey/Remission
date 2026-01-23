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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
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

            #if os(iOS)
                if item.torrent.tags.isEmpty == false {
                    tagsRow
                }
            #endif

            ProgressView(value: item.metrics.progressFraction)
                .tint(progressColor)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("torrent_row_progressbar_\(item.torrent.id.rawValue)")
                .accessibilityValue(item.metrics.progressText)

            #if os(iOS)
                HStack(alignment: .center, spacing: 12) {
                    Label(
                        peersText,
                        systemImage: "person.2"
                    )
                    .appCaption()
                    .foregroundStyle(.primary)

                    Text(ratioTextShort)
                        .appCaption()
                        .foregroundStyle(.primary)
                        .appMonospacedDigit()
                        .accessibilityIdentifier(
                            "torrent_row_ratio_\(item.torrent.id.rawValue)")

                    Spacer(minLength: 6)

                    Label(item.metrics.speedSummary, systemImage: "speedometer")
                        .appCaption()
                        .foregroundStyle(.primary)
                        .appMonospacedDigit()
                        .lineLimit(1)
                        .layoutPriority(1)
                        .accessibilityIdentifier("torrent_row_speed_\(item.torrent.id.rawValue)")
                }
            #else
                HStack(spacing: 12) {
                    Label(item.metrics.progressText, systemImage: "circle.dashed")
                        .appCaption()
                        .foregroundStyle(.primary)
                        .appMonospacedDigit()
                        .accessibilityIdentifier(
                            "torrent_row_progress_\(item.torrent.id.rawValue)")

                    if let etaText = item.metrics.etaText {
                        Label(etaText, systemImage: "clock")
                            .appCaption()
                            .foregroundStyle(.primary)
                            .appMonospacedDigit()
                    }

                    Label(
                        peersText,
                        systemImage: "person.2"
                    )
                    .appCaption()
                    .foregroundStyle(.primary)

                    Label(ratioText, systemImage: "gauge.with.dots.needle.100percent")
                        .appCaption()
                        .foregroundStyle(.primary)
                        .appMonospacedDigit()
                        .accessibilityIdentifier(
                            "torrent_row_ratio_\(item.torrent.id.rawValue)")

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
                        .accessibilityIdentifier(
                            "torrent_row_speed_\(item.torrent.id.rawValue)")
                }
            #endif
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("torrent_row_\(item.torrent.id.rawValue)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.tr("%@, %@, %@, %@"),
                locale: Locale.current,
                item.torrent.name,
                statusTitle,
                item.metrics.progressText,
                item.metrics.speedSummary
            )
        )
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
        #if !os(visionOS)
            .appGlassEffectTransition(.materialize)
        #endif
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

    private func displayTagLabel(_ tag: String) -> String {
        TorrentCategory.localizedTitle(for: tag) ?? tag
    }

    private var peersText: String {
        String(
            format: L10n.tr("torrentList.peers"),
            Int64(item.torrent.summary.peers.connected)
        )
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

    private var statusBadge: some View {
        ZStack {
            Text(statusAbbreviation)
                .font(.subheadline.weight(.semibold))
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(statusColor.opacity(0.15))
        )
        .overlay(
            Circle()
                .strokeBorder(AppTheme.Stroke.subtle(colorScheme))
        )
        .foregroundStyle(statusColor)
        .accessibilityIdentifier("torrent_list_item_status_\(item.id.rawValue)")
        .accessibilityLabel(statusTitle)
    }

    private var statusAbbreviation: String {
        switch item.torrent.status {
        case .stopped:
            return L10n.tr("torrentList.status.abbrev.paused")
        case .checkWaiting, .checking:
            return L10n.tr("torrentList.status.abbrev.checking")
        case .downloadWaiting, .seedWaiting:
            return L10n.tr("torrentList.status.abbrev.waiting")
        case .downloading:
            return L10n.tr("torrentList.status.abbrev.downloading")
        case .seeding:
            return L10n.tr("torrentList.status.abbrev.seeding")
        case .isolated:
            return L10n.tr("torrentList.status.abbrev.error")
        }
    }

    private var statusTitle: String {
        switch item.torrent.status {
        case .stopped: return L10n.tr("torrentList.status.paused")
        case .checkWaiting: return L10n.tr("torrentList.status.checkWaiting")
        case .checking: return L10n.tr("torrentList.status.checking")
        case .downloadWaiting: return L10n.tr("torrentList.status.downloadWaiting")
        case .downloading: return L10n.tr("torrentList.status.downloading")
        case .seedWaiting: return L10n.tr("torrentList.status.seedWaiting")
        case .seeding: return L10n.tr("torrentList.status.seeding")
        case .isolated: return L10n.tr("torrentList.status.error")
        }
    }

    private var statusColor: Color {
        switch item.torrent.status {
        case .downloading: return .blue
        case .seeding: return .green
        case .stopped: return .primary
        case .checking, .checkWaiting: return .orange
        case .downloadWaiting, .seedWaiting: return .purple
        case .isolated: return .red
        }
    }

    private var progressColor: Color {
        statusColor
    }
}
