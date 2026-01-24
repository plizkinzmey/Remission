import ComposableArchitecture
import Foundation

struct TorrentDetailSpeedHistory: Equatable {
    var samples: [SpeedSample] = []
    var capacity: Int = 20

    mutating func append(timestamp: Date, downloadRate: Int, uploadRate: Int) {
        samples.append(
            SpeedSample(
                timestamp: timestamp,
                downloadRate: downloadRate,
                uploadRate: uploadRate
            )
        )
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    mutating func reset() {
        samples.removeAll()
    }
}

struct TorrentDetailPendingStatusChange: Equatable {
    var command: TorrentDetailReducer.CommandKind
    var initialStatus: Int
}

extension TorrentDetailReducer {
    @ObservableState
    struct State: Equatable {
        var torrentID: Torrent.Identifier
        var connectionEnvironment: ServerConnectionEnvironment?
        var name: String = ""
        var status: Int = 0
        var tags: [String] = []
        var category: TorrentCategory = .other
        var lastSyncedTags: [String] = []
        var percentDone: Double = 0.0
        var recheckProgress: Double = 0.0
        var totalSize: Int = 0
        var downloadedEver: Int = 0
        var uploadedEver: Int = 0
        var eta: Int = 0
        var rateDownload: Int = 0
        var rateUpload: Int = 0
        var uploadRatio: Double = 0.0
        var downloadLimit: Int = 0
        var downloadLimited: Bool = false
        var uploadLimit: Int = 0
        var uploadLimited: Bool = false
        var speedHistory: TorrentDetailSpeedHistory = .init()
        var peersConnected: Int = 0
        var peers: IdentifiedArrayOf<PeerSource> = []
        var downloadDir: String = ""
        var dateAdded: Int = 0
        var files: IdentifiedArrayOf<TorrentFile> = []
        var trackers: IdentifiedArrayOf<TorrentTracker> = []
        var trackerStats: IdentifiedArrayOf<TrackerStat> = []
        var hasLoadedMetadata: Bool = false
        var activeCommand: TorrentDetailReducer.CommandKind?
        var pendingCommands: [TorrentDetailReducer.CommandKind] = []
        var pendingStatusChange: TorrentDetailPendingStatusChange?
        var isLoading: Bool = false
        var errorPresenter: ErrorPresenter<TorrentDetailReducer.ErrorRetry>.State = .init()
        var pendingListSync: Bool = false
        @Presents var alert: AlertState<AlertAction>?
        @Presents var removeConfirmation: ConfirmationDialogState<RemoveConfirmationAction>?

        init(
            torrentID: Torrent.Identifier,
            torrent: Torrent? = nil,
            connectionEnvironment: ServerConnectionEnvironment? = nil
        ) {
            self.torrentID = torrentID
            self.connectionEnvironment = connectionEnvironment
            if let torrent {
                self.apply(torrent)
            }
        }

        mutating func applyConnectionEnvironment(
            _ environment: ServerConnectionEnvironment?
        ) {
            connectionEnvironment = environment
            guard environment == nil else { return }
            // Когда окружение теряется, сбрасываем очередь команд,
            // чтобы не выполнять их без активного подключения.
            pendingCommands.removeAll()
            activeCommand = nil
            pendingStatusChange = nil
            pendingListSync = false
        }

        func isCommandCategoryLocked(_ category: TorrentDetailReducer.CommandCategory) -> Bool {
            if let activeCommand, activeCommand.category == category {
                return true
            }
            if let pendingStatusChange, pendingStatusChange.command.category == category {
                return true
            }
            if category == .verify,
                status == Torrent.Status.checkWaiting.rawValue
                    || status == Torrent.Status.checking.rawValue
            {
                return true
            }
            return pendingCommands.contains(where: { $0.category == category })
        }
    }
}

extension TorrentDetailReducer.State {
    mutating func apply(_ torrent: Torrent) {
        torrentID = torrent.id
        name = torrent.name
        status = torrent.status.rawValue
        tags = torrent.tags
        lastSyncedTags = torrent.tags
        category = TorrentCategory.category(from: torrent.tags)
        percentDone = torrent.summary.progress.percentDone
        recheckProgress = torrent.summary.progress.recheckProgress
        totalSize = torrent.summary.progress.totalSize
        downloadedEver = torrent.summary.progress.downloadedEver
        uploadedEver = torrent.summary.progress.uploadedEver
        uploadRatio = torrent.summary.progress.uploadRatio
        eta = torrent.summary.progress.etaSeconds

        rateDownload = torrent.summary.transfer.downloadRate
        rateUpload = torrent.summary.transfer.uploadRate
        downloadLimit = torrent.summary.transfer.downloadLimit.kilobytesPerSecond
        downloadLimited = torrent.summary.transfer.downloadLimit.isEnabled
        uploadLimit = torrent.summary.transfer.uploadLimit.kilobytesPerSecond
        uploadLimited = torrent.summary.transfer.uploadLimit.isEnabled

        peersConnected = torrent.summary.peers.connected
        peers = IdentifiedArray(uniqueElements: torrent.summary.peers.sources)

        if let details = torrent.details {
            hasLoadedMetadata = true
            downloadDir = details.downloadDirectory
            if let addedDate = details.addedDate {
                dateAdded = Int(addedDate.timeIntervalSince1970)
            } else {
                dateAdded = 0
            }
            files = IdentifiedArray(uniqueElements: details.files)
            trackers = IdentifiedArray(uniqueElements: details.trackers)
            trackerStats = IdentifiedArray(uniqueElements: details.trackerStats)
        } else {
            hasLoadedMetadata = false
            downloadDir = ""
            dateAdded = 0
            files = []
            trackers = []
            trackerStats = []
        }

        if let pendingStatusChange, pendingStatusChange.initialStatus != status {
            self.pendingStatusChange = nil
        }
    }
}
