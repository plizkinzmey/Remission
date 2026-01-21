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

extension TorrentDetailReducer {
    @ObservableState
    struct State: Equatable {
        struct PendingStatusChange: Equatable {
            var command: TorrentDetailReducer.CommandKind
            var initialStatus: Int
        }

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
        var pendingStatusChange: PendingStatusChange?
        var isLoading: Bool = false
        var errorPresenter: ErrorPresenter<TorrentDetailReducer.ErrorRetry>.State = .init()
        var pendingListSync: Bool = false
        @Presents var alert: AlertState<AlertAction>?
        @Presents var removeConfirmation: ConfirmationDialogState<RemoveConfirmationAction>?

        init(
            torrentID: Torrent.Identifier,
            connectionEnvironment: ServerConnectionEnvironment? = nil,
            name: String = "",
            status: Int = 0,
            tags: [String] = [],
            category: TorrentCategory = .other,
            lastSyncedTags: [String] = [],
            percentDone: Double = 0.0,
            recheckProgress: Double = 0.0,
            totalSize: Int = 0,
            downloadedEver: Int = 0,
            uploadedEver: Int = 0,
            eta: Int = 0,
            rateDownload: Int = 0,
            rateUpload: Int = 0,
            uploadRatio: Double = 0.0,
            downloadLimit: Int = 0,
            downloadLimited: Bool = false,
            uploadLimit: Int = 0,
            uploadLimited: Bool = false,
            speedHistory: TorrentDetailSpeedHistory = .init(),
            peersConnected: Int = 0,
            peers: [PeerSource] = [],
            downloadDir: String = "",
            dateAdded: Int = 0,
            files: [TorrentFile] = [],
            trackers: [TorrentTracker] = [],
            trackerStats: [TrackerStat] = [],
            hasLoadedMetadata: Bool = false,
            activeCommand: TorrentDetailReducer.CommandKind? = nil,
            pendingCommands: [TorrentDetailReducer.CommandKind] = [],
            pendingStatusChange: PendingStatusChange? = nil,
            isLoading: Bool = false,
            errorPresenter: ErrorPresenter<TorrentDetailReducer.ErrorRetry>.State = .init(),
            pendingListSync: Bool = false
        ) {
            self.torrentID = torrentID
            self.connectionEnvironment = connectionEnvironment
            self.name = name
            self.status = status
            self.tags = tags
            self.category = category
            self.lastSyncedTags = lastSyncedTags
            self.percentDone = percentDone
            self.recheckProgress = recheckProgress
            self.totalSize = totalSize
            self.downloadedEver = downloadedEver
            self.uploadedEver = uploadedEver
            self.eta = eta
            self.rateDownload = rateDownload
            self.rateUpload = rateUpload
            self.uploadRatio = uploadRatio
            self.downloadLimit = downloadLimit
            self.downloadLimited = downloadLimited
            self.uploadLimit = uploadLimit
            self.uploadLimited = uploadLimited
            self.speedHistory = speedHistory
            self.peersConnected = peersConnected
            self.peers = IdentifiedArray(uniqueElements: peers)
            self.downloadDir = downloadDir
            self.dateAdded = dateAdded
            self.files = IdentifiedArray(uniqueElements: files)
            self.trackers = IdentifiedArray(uniqueElements: trackers)
            self.trackerStats = IdentifiedArray(uniqueElements: trackerStats)
            self.hasLoadedMetadata = hasLoadedMetadata
            self.activeCommand = activeCommand
            self.pendingCommands = pendingCommands
            self.pendingStatusChange = pendingStatusChange
            self.isLoading = isLoading
            self.errorPresenter = errorPresenter
            self.pendingListSync = pendingListSync
        }

        init(
            torrent: Torrent,
            connectionEnvironment: ServerConnectionEnvironment? = nil
        ) {
            self.init(torrentID: torrent.id, connectionEnvironment: connectionEnvironment)
            apply(torrent)
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

        @available(*, deprecated, message: "Use torrentID overload")
        init(
            torrentId: Int,
            connectionEnvironment: ServerConnectionEnvironment? = nil,
            name: String = "",
            status: Int = 0,
            tags: [String] = [],
            category: TorrentCategory = .other,
            lastSyncedTags: [String] = [],
            percentDone: Double = 0.0,
            recheckProgress: Double = 0.0,
            totalSize: Int = 0,
            downloadedEver: Int = 0,
            uploadedEver: Int = 0,
            eta: Int = 0,
            rateDownload: Int = 0,
            rateUpload: Int = 0,
            uploadRatio: Double = 0.0,
            downloadLimit: Int = 0,
            downloadLimited: Bool = false,
            uploadLimit: Int = 0,
            uploadLimited: Bool = false,
            speedHistory: TorrentDetailSpeedHistory = .init(),
            peersConnected: Int = 0,
            peers: [PeerSource] = [],
            downloadDir: String = "",
            dateAdded: Int = 0,
            files: [TorrentFile] = [],
            trackers: [TorrentTracker] = [],
            trackerStats: [TrackerStat] = [],
            hasLoadedMetadata: Bool = false,
            activeCommand: TorrentDetailReducer.CommandKind? = nil,
            pendingCommands: [TorrentDetailReducer.CommandKind] = [],
            pendingStatusChange: PendingStatusChange? = nil,
            isLoading: Bool = false,
            errorPresenter: ErrorPresenter<TorrentDetailReducer.ErrorRetry>.State = .init(),
            pendingListSync: Bool = false
        ) {
            self.init(
                torrentID: .init(rawValue: torrentId),
                connectionEnvironment: connectionEnvironment,
                name: name,
                status: status,
                tags: tags,
                category: category,
                lastSyncedTags: lastSyncedTags,
                percentDone: percentDone,
                recheckProgress: recheckProgress,
                totalSize: totalSize,
                downloadedEver: downloadedEver,
                uploadedEver: uploadedEver,
                eta: eta,
                rateDownload: rateDownload,
                rateUpload: rateUpload,
                uploadRatio: uploadRatio,
                downloadLimit: downloadLimit,
                downloadLimited: downloadLimited,
                uploadLimit: uploadLimit,
                uploadLimited: uploadLimited,
                speedHistory: speedHistory,
                peersConnected: peersConnected,
                peers: peers,
                downloadDir: downloadDir,
                dateAdded: dateAdded,
                files: files,
                trackers: trackers,
                trackerStats: trackerStats,
                hasLoadedMetadata: hasLoadedMetadata,
                activeCommand: activeCommand,
                pendingCommands: pendingCommands,
                pendingStatusChange: pendingStatusChange,
                isLoading: isLoading,
                errorPresenter: errorPresenter,
                pendingListSync: pendingListSync
            )
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
