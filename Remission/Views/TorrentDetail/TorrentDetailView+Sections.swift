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
        let percent = max(0, min(100, Int((store.percentDone * 100).rounded())))
        return "\(percent)%"
    }

    var clampedProgress: Double {
        max(0, min(store.percentDone, 1))
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
                        ? TorrentDetailFormatters.progress(store.percentDone)
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
                if store.tags.isEmpty == false {
                    Divider()
                    tagsRow
                }
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

    var tagsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("torrentDetail.mainInfo.tags"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(store.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                            )
                            .foregroundStyle(.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("torrent_detail_tags")
        }
    }

    var advancedSections: some View {
        AppSectionCard("") {
            DisclosureGroup(isExpanded: $isFilesExpanded) {
                if isFilesExpanded {
                    filesContent
                        .padding(.top, 8)
                }
            } label: {
                disclosureHeader(
                    String(
                        format: L10n.tr("torrentDetail.files.title"),
                        Int64(store.files.count)
                    ),
                    isExpanded: $isFilesExpanded
                )
            }
            .accessibilityIdentifier("torrent-files-section")

            DisclosureGroup(isExpanded: $isTrackersExpanded) {
                if isTrackersExpanded {
                    trackersContent
                        .padding(.top, 8)
                }
            } label: {
                disclosureHeader(
                    String(
                        format: L10n.tr("torrentDetail.trackers.title"),
                        Int64(store.trackers.count)
                    ),
                    isExpanded: $isTrackersExpanded
                )
            }
            .accessibilityIdentifier("torrent-trackers-section")

            DisclosureGroup(isExpanded: $isPeersExpanded) {
                if isPeersExpanded {
                    peersContent
                        .padding(.top, 8)
                }
            } label: {
                disclosureHeader(
                    L10n.tr("torrentDetail.peers.title"),
                    isExpanded: $isPeersExpanded
                )
            }
            .accessibilityIdentifier("torrent-peers-section")
        }
    }

    @ViewBuilder
    var filesContent: some View {
        if store.files.isEmpty {
            EmptyPlaceholderView(
                systemImage: "doc.text.magnifyingglass",
                title: store.hasLoadedMetadata
                    ? L10n.tr("torrentDetail.files.empty.title.loaded")
                    : L10n.tr("torrentDetail.files.empty.title.loading"),
                message: store.hasLoadedMetadata
                    ? L10n.tr("torrentDetail.files.empty.message.loaded")
                    : L10n.tr("torrentDetail.files.empty.message.loading")
            )
            .accessibilityIdentifier("torrent-files-empty")
        } else {
            TorrentFilesView(store: store, showsContainer: false)
        }
    }

    @ViewBuilder
    var trackersContent: some View {
        if store.trackers.isEmpty {
            EmptyPlaceholderView(
                systemImage: "dot.radiowaves.left.and.right",
                title: store.hasLoadedMetadata
                    ? L10n.tr("torrentDetail.trackers.empty.title.loaded")
                    : L10n.tr("torrentDetail.trackers.empty.title.loading"),
                message: store.hasLoadedMetadata
                    ? L10n.tr("torrentDetail.trackers.empty.message.loaded")
                    : L10n.tr("torrentDetail.trackers.empty.message.loading")
            )
            .accessibilityIdentifier("torrent-trackers-empty")
        } else {
            TorrentTrackersView(store: store, showsContainer: false)
        }
    }

    @ViewBuilder
    var peersContent: some View {
        if store.peers.isEmpty {
            EmptyPlaceholderView(
                systemImage: "person.2.wave.2.fill",
                title: store.hasLoadedMetadata
                    ? L10n.tr("torrentDetail.peers.empty.title.loaded")
                    : L10n.tr("torrentDetail.peers.empty.title.loading"),
                message: store.hasLoadedMetadata
                    ? L10n.tr("torrentDetail.peers.empty.message.loaded")
                    : L10n.tr("torrentDetail.peers.empty.message.loading")
            )
            .accessibilityIdentifier("torrent-peers-empty")
        } else {
            TorrentPeersView(peers: store.peers, showsContainer: false)
        }
    }

    private func disclosureHeader(
        _ title: String,
        isExpanded: Binding<Bool>
    ) -> some View {
        Button {
            isExpanded.wrappedValue.toggle()
        } label: {
            HStack {
                Text(title)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
