import ComposableArchitecture
import SwiftUI

struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                summarySection

                if let banner = store.errorPresenter.banner {
                    ErrorBannerView(
                        message: banner.message,
                        onRetry: banner.retry == nil
                            ? nil
                            : { store.send(.errorPresenter(.bannerRetryTapped)) },
                        onDismiss: { store.send(.dismissError) }
                    )
                }

                if shouldShowInitialPlaceholder {
                    EmptyPlaceholderView(
                        systemImage: "arrow.clockwise.circle",
                        title: L10n.tr("torrentDetail.placeholder.initial.title"),
                        message: L10n.tr("torrentDetail.placeholder.initial.message")
                    )
                    .accessibilityIdentifier("torrent-detail-initial-placeholder")
                }

                if shouldShowMetadataFallback {
                    EmptyPlaceholderView(
                        systemImage: "sparkles",
                        title: L10n.tr("torrentDetail.placeholder.metadata.title"),
                        message: L10n.tr("torrentDetail.placeholder.metadata.message")
                    )
                    .accessibilityIdentifier("torrent-detail-metadata-placeholder")
                }

                TorrentMainInfoView(store: store)
                TorrentStatisticsView(store: store)
                TorrentSpeedHistoryView(samples: store.speedHistory.samples)
                TorrentActionsView(store: store)
                filesSection
                trackersSection
                peersSection
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .navigationTitle(store.name.isEmpty ? L10n.tr("torrentDetail.title.fallback") : store.name)
        #if !os(macOS)
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
        .onDisappear {
            store.send(.teardown)
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
    private var filesSection: some View {
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
            TorrentFilesView(store: store)
        }
    }

    @ViewBuilder
    private var trackersSection: some View {
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
            TorrentTrackersView(store: store)
        }
    }

    @ViewBuilder
    private var peersSection: some View {
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
            TorrentPeersView(peers: store.peers)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ProgressView(
                        value: store.hasLoadedMetadata ? store.percentDone : 0,
                        total: 1.0
                    )
                    .progressViewStyle(.circular)
                    .frame(width: 52, height: 52)
                    .accessibilityLabel(L10n.tr("torrentDetail.progress.accessibility"))
                    .accessibilityValue(progressDescription)
                    .accessibilityIdentifier("torrent-progress")
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
                Divider()
                summaryMetrics
            }
        } label: {
            Text(L10n.tr("torrentDetail.section.summary"))
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-summary")
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
                icon: "person.3.sequence.fill",
                title: L10n.tr("torrentDetail.metric.peers"),
                value: "\(store.peersConnected)"
            )
        }
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
}

private struct SummaryMetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
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
