import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Torrent List View Coverage")
@MainActor
struct TorrentListViewCoverageTests {
    @Test
    func torrentListViewRendersLoadedAndEmptyStates() {
        var loadedState = TorrentListReducer.State.previewLoaded()
        loadedState.isRefreshing = true
        loadedState.errorPresenter.banner = .init(
            message: "Network error",
            retry: .refresh
        )
        let loadedStore = Store(initialState: loadedState) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let loadedView = TorrentListView(store: loadedStore)
        _ = loadedView.body

        var emptyState = TorrentListReducer.State.previewEmpty()
        emptyState.isRefreshing = false
        let emptyStore = Store(initialState: emptyState) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let emptyView = TorrentListView(store: emptyStore)
        _ = emptyView.body

        let loadedItems = loadedStore.state.visibleItems
        let emptyItems = emptyStore.state.visibleItems
        #expect(!loadedItems.isEmpty)
        #expect(emptyItems.isEmpty)
    }

    @Test
    func torrentListViewRendersLoadingOfflineAndErrorStates() {
        var loadingState = TorrentListReducer.State.previewLoading()
        loadingState.isRefreshing = false
        let loadingStore = Store(initialState: loadingState) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let loadingView = TorrentListView(store: loadingStore)
        _ = loadingView.body

        var offlineState = TorrentListReducer.State.previewError()
        offlineState.phase = .offline(
            .init(message: "Offline", lastUpdatedAt: Date())
        )
        let offlineStore = Store(initialState: offlineState) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let offlineView = TorrentListView(store: offlineStore)
        _ = offlineView.body

        var errorState = TorrentListReducer.State.previewBase()
        errorState.phase = .error("Boom")
        errorState.items = []
        let errorStore = Store(initialState: errorState) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let errorView = TorrentListView(store: errorStore)
        _ = errorView.body

        let phase = errorStore.state.phase
        #expect(phase == .error("Boom"))
    }

    @Test
    func torrentListComponentsRender() {
        let header = TorrentListHeaderView(title: "Header")
        _ = header.body

        let controlsStore = Store(initialState: TorrentListReducer.State.previewLoaded()) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }
        let controls = TorrentListControlsView(store: controlsStore)
        _ = controls.body

        let summary = TorrentListStorageSummaryView(
            summary: StorageSummary(totalBytes: 1_000, freeBytes: 400)
        )
        _ = summary.body

        let empty = TorrentListEmptyStateView()
        _ = empty.body

        let background = TorrentRowBackgroundView(isIsolated: true)
        _ = background.body

        let skeleton = TorrentRowSkeletonView(index: 3)
        _ = skeleton.body
    }

    @Test
    func torrentRowViewRendersWithActions() {
        let torrent = Torrent.sampleDownloading()
        let item = TorrentListItem.State(torrent: torrent)
        let actions = TorrentRowView.RowActions(
            isActive: true,
            isLocked: false,
            isStartPauseBusy: false,
            isVerifyBusy: true,
            isRemoveBusy: false,
            onStartPause: {},
            onVerify: {},
            onRemove: {}
        )
        let view = TorrentRowView(
            item: item,
            openRequested: {},
            actions: actions,
            longestStatusTitle: "Downloading",
            isLocked: false
        )
        _ = view.body

        #expect(item.torrent.name.isEmpty == false)
    }

    @Test
    func torrentListToolbarControlsRender() {
        var state = TorrentListReducer.State.previewLoaded()
        state.searchQuery = "Ubuntu"
        let store = Store(initialState: state) {
            TorrentListReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let view = TorrentListView(store: store)
        #if os(macOS)
            _ = view.macOSToolbarControls
        #endif

        let query = store.state.searchQuery
        #expect(query == "Ubuntu")
    }

    @Test
    func torrentListPreviewHelpersAreCallable() {
        _ = TorrentListReducer.State.previewBase()
        _ = TorrentListReducer.State.previewLoaded()
        _ = TorrentListReducer.State.previewLoading()
        _ = TorrentListReducer.State.previewEmpty()
        _ = TorrentListReducer.State.previewError()
    }
}
