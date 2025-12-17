import ComposableArchitecture
import SwiftUI

struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    @State private var isSpeedHistoryExpanded: Bool = false
    @State private var isStatisticsExpanded: Bool = false
    @State private var isFilesExpanded: Bool = false
    @State private var isTrackersExpanded: Bool = false
    @State private var isPeersExpanded: Bool = false

    var body: some View {
        Form {
            summarySection
            basicInformationSection

            if let banner = store.errorPresenter.banner {
                Section {
                    ErrorBannerView(
                        message: banner.message,
                        onRetry: banner.retry == nil
                            ? nil
                            : { store.send(.errorPresenter(.bannerRetryTapped)) },
                        onDismiss: { store.send(.dismissError) }
                    )
                }
            }

            if shouldShowInitialPlaceholder {
                Section {
                    EmptyPlaceholderView(
                        systemImage: "arrow.clockwise.circle",
                        title: L10n.tr("torrentDetail.placeholder.initial.title"),
                        message: L10n.tr("torrentDetail.placeholder.initial.message")
                    )
                    .accessibilityIdentifier("torrent-detail-initial-placeholder")
                }
            }

            if shouldShowMetadataFallback {
                Section {
                    EmptyPlaceholderView(
                        systemImage: "sparkles",
                        title: L10n.tr("torrentDetail.placeholder.metadata.title"),
                        message: L10n.tr("torrentDetail.placeholder.metadata.message")
                    )
                    .accessibilityIdentifier("torrent-detail-metadata-placeholder")
                }
            }

            advancedSections
        }
        .formStyle(.grouped)
        #if os(macOS)
            .padding(.top, -20)
        #endif
        #if os(macOS)
            .navigationTitle("")
        #else
            .navigationTitle(
                store.name.isEmpty
                    ? L10n.tr("torrentDetail.title.fallback")
                    : store.name
            )
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await store.send(.task).finish()
        }
        .refreshable {
            await store.send(.refreshRequested).finish()
        }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .alert(
            $store.scope(state: \.errorPresenter.alert, action: \.errorPresenter.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
        )
        .overlay(alignment: .center) {
            if store.isLoading {
                loadingOverlay
            }
        }
    }

    private var shouldShowInitialPlaceholder: Bool {
        store.isLoading
            && store.files.isEmpty
            && store.trackers.isEmpty
            && store.peers.isEmpty
            && store.speedHistory.samples.isEmpty
    }

    private var shouldShowMetadataFallback: Bool {
        store.isLoading == false
            && store.errorPresenter.banner == nil
            && store.hasLoadedMetadata == false
            && store.files.isEmpty
            && store.trackers.isEmpty
            && store.peers.isEmpty
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    summaryHeaderWide
                    summaryHeaderNarrow
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text(L10n.tr("torrentDetail.section.summary"))
        }
        .accessibilityIdentifier("torrent-summary")
    }

    private var summaryHeaderWide: some View {
        HStack(alignment: .center, spacing: 16) {
            summaryProgressView
            summaryStatusStack
            Spacer(minLength: 12)
            summaryMetricsCompact
        }
    }

    private var summaryHeaderNarrow: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                summaryProgressView
                summaryStatusStack
                Spacer(minLength: 8)
            }
            Divider()
            summaryMetrics
        }
    }

    private var summaryProgressView: some View {
        ProgressView(
            value: store.hasLoadedMetadata ? store.percentDone : 0,
            total: 1.0
        )
        .progressViewStyle(.circular)
        .frame(width: 52, height: 52)
        .accessibilityLabel(L10n.tr("torrentDetail.progress.accessibility"))
        .accessibilityValue(progressDescription)
        .accessibilityIdentifier("torrent-progress")
    }

    private var summaryStatusStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(progressDescription)
                .font(.title3.weight(.semibold))
            Text(TorrentDetailFormatters.statusText(for: store.status))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if store.eta > 0 {
                Text(
                    String(
                        format: L10n.tr("torrentDetail.eta.remaining"),
                        TorrentDetailFormatters.eta(store.eta)
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else if store.hasLoadedMetadata {
                Text(L10n.tr("torrentDetail.eta.unavailable"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(L10n.tr("torrentDetail.eta.waitMetadata"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summaryMetrics: some View {
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

    private var summaryMetricsCompact: some View {
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

    private var progressDescription: String {
        guard store.hasLoadedMetadata else {
            return L10n.tr("torrentDetail.progress.none")
        }
        let percent = max(0, min(100, Int((store.percentDone * 100).rounded())))
        return "\(percent)%"
    }

    private var loadingOverlay: some View {
        ProgressView(L10n.tr("torrentDetail.loading"))
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .accessibilityIdentifier("torrent-detail-loading")
    }

    private var basicInformationSection: some View {
        Section {
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.status"),
                value: TorrentDetailFormatters.statusText(for: store.status)
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.progress"),
                value: store.hasLoadedMetadata
                    ? TorrentDetailFormatters.progress(store.percentDone)
                    : L10n.tr("torrentDetail.mainInfo.unavailable")
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.size"),
                value: store.hasLoadedMetadata && store.totalSize > 0
                    ? TorrentDetailFormatters.bytes(store.totalSize)
                    : L10n.tr("torrentDetail.mainInfo.unknown")
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.downloaded"),
                value: store.hasLoadedMetadata
                    ? TorrentDetailFormatters.bytes(store.downloadedEver)
                    : L10n.tr("torrentDetail.mainInfo.unavailable")
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.uploaded"),
                value: store.hasLoadedMetadata
                    ? TorrentDetailFormatters.bytes(store.uploadedEver)
                    : L10n.tr("torrentDetail.mainInfo.unavailable")
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.path"),
                value: store.hasLoadedMetadata && store.downloadDir.isEmpty == false
                    ? store.downloadDir
                    : L10n.tr("torrentDetail.mainInfo.unknown")
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.added"),
                value: store.hasLoadedMetadata && store.dateAdded > 0
                    ? TorrentDetailFormatters.date(from: store.dateAdded)
                    : L10n.tr("torrentDetail.mainInfo.unavailable")
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.mainInfo.eta"),
                value: etaDescription
            )
        } header: {
            Text(L10n.tr("torrentDetail.mainInfo.title"))
        }
        .accessibilityIdentifier("torrent-main-info")
    }

    private var etaDescription: String {
        if store.eta > 0 {
            return TorrentDetailFormatters.eta(store.eta)
        }
        return store.hasLoadedMetadata
            ? L10n.tr("torrentDetail.mainInfo.unknown")
            : L10n.tr("torrentDetail.mainInfo.waitingMetadata")
    }

    private var advancedSections: some View {
        Section {
            DisclosureGroup(
                isExpanded: $isStatisticsExpanded
            ) {
                if isStatisticsExpanded {
                    TorrentStatisticsView(store: store, showsContainer: false)
                        .padding(.top, 8)
                }
            } label: {
                Text(L10n.tr("torrentDetail.stats.title"))
            }
            .accessibilityIdentifier("torrent-statistics-section")

            DisclosureGroup(
                isExpanded: $isSpeedHistoryExpanded
            ) {
                if isSpeedHistoryExpanded {
                    TorrentSpeedHistoryView(
                        samples: store.speedHistory.samples,
                        showsContainer: false
                    )
                    .padding(.top, 8)
                }
            } label: {
                Text(L10n.tr("torrentDetail.speedHistory.title"))
            }
            .accessibilityIdentifier("torrent-speed-history-section")

            DisclosureGroup(isExpanded: $isFilesExpanded) {
                if isFilesExpanded {
                    filesContent
                        .padding(.top, 8)
                }
            } label: {
                Text(
                    String(
                        format: L10n.tr("torrentDetail.files.title"),
                        Int64(store.files.count)
                    )
                )
            }
            .accessibilityIdentifier("torrent-files-section")

            DisclosureGroup(isExpanded: $isTrackersExpanded) {
                if isTrackersExpanded {
                    trackersContent
                        .padding(.top, 8)
                }
            } label: {
                Text(
                    String(
                        format: L10n.tr("torrentDetail.trackers.title"),
                        Int64(store.trackers.count)
                    )
                )
            }
            .accessibilityIdentifier("torrent-trackers-section")

            DisclosureGroup(isExpanded: $isPeersExpanded) {
                if isPeersExpanded {
                    peersContent
                        .padding(.top, 8)
                }
            } label: {
                Text(L10n.tr("torrentDetail.peers.title"))
            }
            .accessibilityIdentifier("torrent-peers-section")
        }
    }

    @ViewBuilder
    private var filesContent: some View {
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
    private var trackersContent: some View {
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
    private var peersContent: some View {
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
}

private struct SummaryMetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.tr("%@: %@"),
                locale: Locale.current,
                title,
                value
            )
        )
    }
}

private struct SummaryMetricCompactRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    #Preview {
        let previewState: TorrentDetailReducer.State = {
            var state = TorrentDetailReducer.State(
                torrentID: .init(rawValue: 1),
                name: "Ubuntu 22.04 LTS Desktop",
                status: 4,
                percentDone: 0.45,
                totalSize: 3_500_000_000,
                downloadedEver: 1_575_000_000,
                uploadedEver: 500_000_000,
                eta: 3600,
                rateDownload: 2_500_000,
                rateUpload: 500_000,
                uploadRatio: 0.32,
                downloadLimit: 1_024,
                downloadLimited: false,
                uploadLimit: 512,
                uploadLimited: true,
                peersConnected: 45,
                peers: [
                    PeerSource(name: "Tracker", count: 30),
                    PeerSource(name: "DHT", count: 10),
                    PeerSource(name: "PEX", count: 5)
                ],
                downloadDir: "/downloads/ubuntu",
                dateAdded: Int(Date().timeIntervalSince1970) - 3600,
                files: [
                    TorrentFile(
                        index: 0,
                        name: "ubuntu-22.04-desktop-amd64.iso",
                        length: 3_500_000_000,
                        bytesCompleted: 1_575_000_000,
                        priority: 1,
                        wanted: true
                    )
                ],
                trackers: [
                    TorrentTracker(
                        id: 0,
                        announce: "https://torrent.ubuntu.com/announce",
                        tier: 0
                    )
                ],
                trackerStats: [
                    TrackerStat(
                        trackerId: 0,
                        lastAnnounceResult: "Success",
                        downloadCount: 1_000,
                        leecherCount: 150,
                        seederCount: 350
                    )
                ],
                isLoading: false
            )
            state.hasLoadedMetadata = true
            state.speedHistory.samples = [
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-120),
                    downloadRate: 2_500_000,
                    uploadRate: 500_000
                ),
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-60),
                    downloadRate: 2_800_000,
                    uploadRate: 520_000
                ),
                SpeedSample(
                    timestamp: Date(),
                    downloadRate: 3_050_000,
                    uploadRate: 540_000
                )
            ]
            return state
        }()

        NavigationStack {
            TorrentDetailView(
                store: Store(
                    initialState: previewState
                ) {
                    TorrentDetailReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }
#endif
