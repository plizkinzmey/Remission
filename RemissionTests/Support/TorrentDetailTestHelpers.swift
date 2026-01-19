import ComposableArchitecture
import Foundation

@testable import Remission

@MainActor
func makeDetailStore(
    torrent: Torrent,
    repository: TorrentRepository,
    timestamp: Date
) -> TestStoreOf<TorrentDetailReducer> {
    let environment = makeEnvironment(repository: repository)
    var initialState = TorrentDetailReducer.State(
        torrentID: torrent.id,
        connectionEnvironment: environment
    )
    initialState.apply(torrent)
    return TestStoreFactory.make(
        initialState: initialState,
        reducer: { TorrentDetailReducer() },
        configure: { dependencies in
            dependencies.torrentRepository = repository
            dependencies.dateProvider.now = { timestamp }
        }
    )
}

func assign(
    _ state: inout TorrentDetailReducer.State,
    from torrent: Torrent
) {
    state.name = torrent.name
    state.status = torrent.status.rawValue
    state.tags = torrent.tags
    state.lastSyncedTags = torrent.tags
    state.category = TorrentCategory.category(from: torrent.tags)
    state.percentDone = torrent.summary.progress.percentDone
    state.totalSize = torrent.summary.progress.totalSize
    state.downloadedEver = torrent.summary.progress.downloadedEver
    state.uploadedEver = torrent.summary.progress.uploadedEver
    state.uploadRatio = torrent.summary.progress.uploadRatio
    state.eta = torrent.summary.progress.etaSeconds

    state.rateDownload = torrent.summary.transfer.downloadRate
    state.rateUpload = torrent.summary.transfer.uploadRate
    state.downloadLimit = torrent.summary.transfer.downloadLimit.kilobytesPerSecond
    state.downloadLimited = torrent.summary.transfer.downloadLimit.isEnabled
    state.uploadLimit = torrent.summary.transfer.uploadLimit.kilobytesPerSecond
    state.uploadLimited = torrent.summary.transfer.uploadLimit.isEnabled

    state.peersConnected = torrent.summary.peers.connected
    state.peers = IdentifiedArray(uniqueElements: torrent.summary.peers.sources)

    if let details = torrent.details {
        state.downloadDir = details.downloadDirectory
        if let addedDate = details.addedDate {
            state.dateAdded = Int(addedDate.timeIntervalSince1970)
        } else {
            state.dateAdded = 0
        }
        state.files = IdentifiedArray(uniqueElements: details.files)
        state.trackers = IdentifiedArray(uniqueElements: details.trackers)
        state.trackerStats = IdentifiedArray(uniqueElements: details.trackerStats)
    } else {
        state.files = []
        state.trackers = []
        state.trackerStats = []
        state.downloadDir = ""
        state.dateAdded = 0
    }
    state.hasLoadedMetadata = torrent.details != nil
}

func makeEnvironment(
    repository: TorrentRepository
) -> ServerConnectionEnvironment {
    ServerConnectionEnvironment.testEnvironment(
        server: .previewLocalHTTP,
        torrentRepository: repository
    )
}
