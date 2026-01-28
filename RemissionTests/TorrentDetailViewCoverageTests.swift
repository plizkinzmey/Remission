import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Torrent Detail View Coverage")
@MainActor
struct TorrentDetailViewCoverageTests {
    @Test
    func summarySectionRendersForActiveAndIdleStates() {
        let activeStore = makeDetailStore(torrent: makeTorrent(withDetails: true))
        let activeView = TorrentDetailSummarySection(store: activeStore)
        _ = activeView.body

        var idleTorrent = makeTorrent(withDetails: false)
        idleTorrent.status = .stopped
        let idleStore = makeDetailStore(torrent: idleTorrent)
        let idleView = TorrentDetailSummarySection(store: idleStore)
        _ = idleView.body

        #expect(activeStore.withState { $0.status == Torrent.Status.downloading.rawValue })
        #expect(idleStore.withState { $0.status == Torrent.Status.stopped.rawValue })
    }

    @Test
    func infoAndAdvancedSectionsRenderWithMetadata() {
        let store = makeDetailStore(torrent: makeTorrent(withDetails: true))

        let infoView = TorrentDetailInfoSection(store: store)
        _ = infoView.body

        var filesExpanded = true
        var trackersExpanded = true
        var peersExpanded = true
        let advancedView = TorrentDetailAdvancedSection(
            store: store,
            isFilesExpanded: Binding(
                get: { filesExpanded },
                set: { filesExpanded = $0 }
            ),
            isTrackersExpanded: Binding(
                get: { trackersExpanded },
                set: { trackersExpanded = $0 }
            ),
            isPeersExpanded: Binding(
                get: { peersExpanded },
                set: { peersExpanded = $0 }
            )
        )
        _ = advancedView.body

        #expect(store.withState { $0.hasLoadedMetadata })
    }

    @Test
    func detailViewRendersPlaceholdersAndErrors() {
        var loadingState = TorrentDetailReducer.State(torrentID: .init(rawValue: 7))
        loadingState.isLoading = true
        let loadingStore = Store(initialState: loadingState) {
            TorrentDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }
        let loadingView = TorrentDetailView(store: loadingStore)
        _ = loadingView.body

        var fallbackState = TorrentDetailReducer.State(torrentID: .init(rawValue: 8))
        fallbackState.isLoading = false
        fallbackState.hasLoadedMetadata = false
        fallbackState.errorPresenter.banner = .init(message: "Error", retry: .reloadDetails)
        let fallbackStore = Store(initialState: fallbackState) {
            TorrentDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }
        let fallbackView = TorrentDetailView(store: fallbackStore)
        _ = fallbackView.body

        #expect(loadingStore.withState { $0.isLoading })
        #expect(fallbackStore.withState { $0.errorPresenter.banner != nil })
    }

    @Test
    func detailSubviewsRender() {
        let store = makeDetailStore(torrent: makeTorrent(withDetails: true))

        let actions = TorrentActionsView(store: store)
        _ = actions.body

        let statistics = TorrentStatisticsView(store: store)
        _ = statistics.body

        let files = TorrentFilesView(store: store, showsContainer: false)
        _ = files.body

        let trackers = TorrentTrackersView(store: store, showsContainer: false)
        _ = trackers.body

        let peers = TorrentPeersView(
            peers: IdentifiedArray(
                uniqueElements: [
                    PeerSource(name: "DHT", count: 8),
                    PeerSource(name: "Tracker", count: 12)
                ]
            ),
            showsContainer: false
        )
        _ = peers.body

        let speedHistory = TorrentSpeedHistoryView(samples: makeSpeedSamples())
        _ = speedHistory.body

        let speedHistoryEmpty = TorrentSpeedHistoryView(samples: [])
        _ = speedHistoryEmpty.body

        let mainInfo = TorrentMainInfoView(store: store)
        _ = mainInfo.body

        let compactMetric = SummaryMetricCompactRow(
            icon: "arrow.down",
            title: "Download",
            value: "10 MB/s"
        )
        let metric = SummaryMetricRow(
            icon: "arrow.up",
            title: "Upload",
            value: "1 MB/s"
        )
        _ = compactMetric.body
        _ = metric.body

        let labelValue = TorrentDetailLabelValueRow(
            label: "Progress",
            value: "50%",
            monospacedValue: true
        )
        _ = labelValue.body
    }

    @Test
    func detailSectionRendersEmptyAndContentStates() {
        var expanded = true
        let emptySection = TorrentDetailSection(
            title: "Files",
            isExpanded: Binding(get: { expanded }, set: { expanded = $0 }),
            hasMetadata: false,
            isEmpty: true,
            emptyIcon: "doc",
            emptyTitleLoaded: "No files",
            emptyTitleLoading: "Loading files",
            emptyMessageLoaded: "None",
            emptyMessageLoading: "Please wait",
            accessibilityIdentifier: "torrent-files-section"
        ) {
            Text("Content")
        }
        _ = emptySection.body

        var expandedContent = true
        let contentSection = TorrentDetailSection(
            title: "Trackers",
            isExpanded: Binding(get: { expandedContent }, set: { expandedContent = $0 }),
            hasMetadata: true,
            isEmpty: false,
            emptyIcon: "dot.radiowaves.left.and.right",
            emptyTitleLoaded: "No trackers",
            emptyTitleLoading: "Loading trackers",
            emptyMessageLoaded: "None",
            emptyMessageLoading: "Please wait",
            accessibilityIdentifier: "torrent-trackers-section"
        ) {
            Text("Trackers")
        }
        _ = contentSection.body
    }

    @Test
    func previewStateIsCallable() {
        let state = TorrentDetailReducer.State.preview()
        #expect(state.name.isEmpty == false)
    }
}

@MainActor
private func makeDetailStore(torrent: Torrent) -> StoreOf<TorrentDetailReducer> {
    var state = TorrentDetailReducer.State(torrentID: torrent.id)
    state.apply(torrent)
    if let details = torrent.details {
        state.speedHistory.samples = details.speedSamples
    }

    return Store(initialState: state) {
        TorrentDetailReducer()
    } withDependencies: {
        $0 = AppDependencies.makeTestDefaults()
    }
}

private func makeTorrent(withDetails: Bool) -> Torrent {
    var torrent = Torrent.sampleDownloading()
    torrent.summary.peers = .init(
        connected: 4,
        sources: [PeerSource(name: "Tracker", count: 4)]
    )

    if withDetails {
        let files = [
            Torrent.File(
                index: 0,
                name: "README.txt",
                length: 1_024,
                bytesCompleted: 512,
                priority: 0,
                wanted: true
            ),
            Torrent.File(
                index: 1,
                name: "Movie.mkv",
                length: 2_000_000,
                bytesCompleted: 500_000,
                priority: 1,
                wanted: true
            )
        ]
        let trackers = [
            Torrent.Tracker(id: 1, announce: "https://tracker.example.com", tier: 0)
        ]
        let trackerStats = [
            Torrent.TrackerStat(
                trackerId: 1,
                lastAnnounceResult: "Success",
                downloadCount: 10,
                leecherCount: 3,
                seederCount: 7
            )
        ]
        let speedSamples = makeSpeedSamples()
        torrent.details = Torrent.Details(
            downloadDirectory: "/downloads",
            addedDate: Date(timeIntervalSince1970: 1_700_000_000),
            files: files,
            trackers: trackers,
            trackerStats: trackerStats,
            speedSamples: speedSamples
        )
    } else {
        torrent.details = nil
    }

    return torrent
}

private func makeSpeedSamples() -> [SpeedSample] {
    [
        SpeedSample(
            timestamp: Date().addingTimeInterval(-120),
            downloadRate: 2_200_000,
            uploadRate: 200_000
        ),
        SpeedSample(
            timestamp: Date().addingTimeInterval(-60),
            downloadRate: 2_600_000,
            uploadRate: 240_000
        ),
        SpeedSample(
            timestamp: Date(),
            downloadRate: 3_000_000,
            uploadRate: 280_000
        )
    ]
}
