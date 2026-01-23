import ComposableArchitecture
import SwiftUI

extension TorrentDetailView {
    @ViewBuilder
    var summarySection: some View {
        AppSectionCard(L10n.tr("torrentDetail.section.summary")) {
            ViewThatFits(in: .horizontal) {
                summaryHeaderWide
                summaryHeaderNarrow
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("torrent-summary")
    }

    var summaryHeaderWide: some View {
        Group {
            if shouldShowTransferMetrics {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 12)
                    summaryMetricsCompact
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 0)
                }
            }
        }
    }

    var summaryHeaderNarrow: some View {
        Group {
            if shouldShowTransferMetrics {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 8)
                    summaryMetricsCompact
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 0)
                }
            }
        }
    }

    var summaryProgressView: some View {
        let progress = store.hasLoadedMetadata ? clampedProgress : 0
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 52, height: 52)
        .accessibilityLabel(L10n.tr("torrentDetail.progress.accessibility"))
        .accessibilityValue(progressDescription)
        .accessibilityIdentifier("torrent-progress")
    }

    var summaryStatusStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(progressDescription)
                .font(.title3.weight(.semibold))
            Text(TorrentDetailFormatters.statusText(for: store.status))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    var summaryMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            SummaryMetricRow(
                icon: "arrow.down.circle.fill",
                title: L10n.tr("torrentDetail.metric.downloadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateDownload)
            )
            SummaryMetricRow(
                icon: "arrow.up.circle.fill",
                title: L10n.tr("torrentDetail.metric.uploadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateUpload)
            )
            SummaryMetricRow(
                icon: "person.fill",
                title: L10n.tr("torrentDetail.metric.peers"),
                value: "\(store.peersConnected)"
            )
            #if os(macOS)
                SummaryMetricRow(
                    icon: "gauge.with.dots.needle.100percent",
                    title: L10n.tr("torrentDetail.metric.ratio"),
                    value: String(format: "%.2f", store.uploadRatio)
                )
            #endif
        }
    }

    var summaryMetricsCompact: some View {
        VStack(alignment: .leading, spacing: 10) {
            SummaryMetricCompactRow(
                icon: "arrow.down.circle.fill",
                title: L10n.tr("torrentDetail.metric.downloadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateDownload)
            )
            SummaryMetricCompactRow(
                icon: "arrow.up.circle.fill",
                title: L10n.tr("torrentDetail.metric.uploadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateUpload)
            )
            SummaryMetricCompactRow(
                icon: "person.fill",
                title: L10n.tr("torrentDetail.metric.peers"),
                value: "\(store.peersConnected)"
            )
            #if os(macOS)
                SummaryMetricCompactRow(
                    icon: "gauge.with.dots.needle.100percent",
                    title: L10n.tr("torrentDetail.metric.ratio"),
                    value: String(format: "%.2f", store.uploadRatio)
                )
            #endif
        }
        .frame(minWidth: 180, alignment: .leading)
    }

    var summaryStatusCluster: some View {
        HStack(alignment: .top, spacing: 16) {
            summaryProgressView
            summaryStatusStack
        }
    }

    var progressDescription: String {
        guard store.hasLoadedMetadata else {
            return L10n.tr("torrentDetail.progress.none")
        }
        let percent = max(0, min(100, Int((effectiveProgress * 100).rounded())))
        return "\(percent)%"
    }

    var clampedProgress: Double {
        max(0, min(effectiveProgress, 1))
    }

    var effectiveProgress: Double {
        switch store.status {
        case Torrent.Status.checkWaiting.rawValue,
            Torrent.Status.checking.rawValue:
            return store.recheckProgress
        default:
            return store.percentDone
        }
    }

    var loadingOverlay: some View {
        ProgressView(L10n.tr("torrentDetail.loading"))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .accessibilityIdentifier("torrent-detail-loading")
    }

    var basicInformationSection: some View {
        AppSectionCard(L10n.tr("torrentDetail.mainInfo.title")) {
            VStack(alignment: .leading, spacing: 10) {
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.status"),
                    value: TorrentDetailFormatters.statusText(for: store.status)
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.progress"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.progress(effectiveProgress)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.size"),
                    value: store.hasLoadedMetadata && store.totalSize > 0
                        ? TorrentDetailFormatters.bytes(store.totalSize)
                        : L10n.tr("torrentDetail.mainInfo.unknown")
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.downloaded"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.downloadedEver)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.uploaded"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.uploadedEver)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.path"),
                    value: store.hasLoadedMetadata && store.downloadDir.isEmpty == false
                        ? store.downloadDir
                        : L10n.tr("torrentDetail.mainInfo.unknown")
                )
                Divider()
                categoryRow
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.added"),
                    value: store.hasLoadedMetadata && store.dateAdded > 0
                        ? TorrentDetailFormatters.date(from: store.dateAdded)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                if shouldShowEtaRow {
                    Divider()
                    TorrentDetailLabelValueRow(
                        label: L10n.tr("torrentDetail.mainInfo.eta"),
                        value: etaDescription
                    )
                }
            }
        }
        .accessibilityIdentifier("torrent-main-info")
    }

    var etaDescription: String {
        if store.eta > 0 {
            return TorrentDetailFormatters.eta(store.eta)
        }
        return store.hasLoadedMetadata
            ? L10n.tr("torrentDetail.mainInfo.unknown")
            : L10n.tr("torrentDetail.mainInfo.waitingMetadata")
    }

    private var shouldShowTransferMetrics: Bool {
        isDownloading || isSeeding
    }

    private var shouldShowEtaRow: Bool {
        isDownloading || isSeeding
    }

    private var isDownloading: Bool {
        store.status == Torrent.Status.downloading.rawValue
    }

    private var isSeeding: Bool {
        store.status == Torrent.Status.seeding.rawValue
    }

    var categoryRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.tr("torrentDetail.mainInfo.category"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            #if os(macOS)
                Menu {
                    ForEach(TorrentCategory.ordered, id: \.self) { category in
                        Button(category.title) {
                            store.send(.categoryChanged(category))
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(store.category.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(width: 170, height: 34)
                    .contentShape(Rectangle())
                    .appToolbarPillSurface()
                }
                .accessibilityIdentifier("torrent_detail_category_picker")
                .buttonStyle(.plain)
            #else
                Picker(
                    "",
                    selection: Binding(
                        get: { store.category },
                        set: { store.send(.categoryChanged($0)) }
                    )
                ) {
                    ForEach(TorrentCategory.ordered, id: \.self) { category in
                        Text(category.title)
                            .tag(category)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier("torrent_detail_category_picker")
            #endif
        }
    }

    var advancedSections: some View {
        AppSectionCard("") {
            TorrentDetailSection(
                title: String(format: L10n.tr("torrentDetail.files.title"), Int64(store.files.count)),
                isExpanded: $isFilesExpanded,
                hasMetadata: store.hasLoadedMetadata,
                isEmpty: store.files.isEmpty,
                emptyIcon: "doc.text.magnifyingglass",
                emptyTitleLoaded: L10n.tr("torrentDetail.files.empty.title.loaded"),
                emptyTitleLoading: L10n.tr("torrentDetail.files.empty.title.loading"),
                emptyMessageLoaded: L10n.tr("torrentDetail.files.empty.message.loaded"),
                emptyMessageLoading: L10n.tr("torrentDetail.files.empty.message.loading"),
                accessibilityIdentifier: "torrent-files-section"
            ) {
                TorrentFilesView(store: store, showsContainer: false)
            }

            TorrentDetailSection(
                title: String(
                    format: L10n.tr("torrentDetail.trackers.title"),
                    Int64(store.trackers.count)
                ),
                isExpanded: $isTrackersExpanded,
                hasMetadata: store.hasLoadedMetadata,
                isEmpty: store.trackers.isEmpty,
                emptyIcon: "dot.radiowaves.left.and.right",
                emptyTitleLoaded: L10n.tr("torrentDetail.trackers.empty.title.loaded"),
                emptyTitleLoading: L10n.tr("torrentDetail.trackers.empty.title.loading"),
                emptyMessageLoaded: L10n.tr("torrentDetail.trackers.empty.message.loaded"),
                emptyMessageLoading: L10n.tr("torrentDetail.trackers.empty.message.loading"),
                accessibilityIdentifier: "torrent-trackers-section"
            ) {
                TorrentTrackersView(store: store, showsContainer: false)
            }

            TorrentDetailSection(
                title: L10n.tr("torrentDetail.peers.title"),
                isExpanded: $isPeersExpanded,
                hasMetadata: store.hasLoadedMetadata,
                isEmpty: store.peers.isEmpty,
                emptyIcon: "person.2.wave.2.fill",
                emptyTitleLoaded: L10n.tr("torrentDetail.peers.empty.title.loaded"),
                emptyTitleLoading: L10n.tr("torrentDetail.peers.empty.title.loading"),
                emptyMessageLoaded: L10n.tr("torrentDetail.peers.empty.message.loaded"),
                emptyMessageLoading: L10n.tr("torrentDetail.peers.empty.message.loading"),
                accessibilityIdentifier: "torrent-peers-section"
            ) {
                TorrentPeersView(peers: store.peers, showsContainer: false)
            }
        }
    }
}
