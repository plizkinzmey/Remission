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
        var torrentID: Torrent.Identifier
        var connectionEnvironment: ServerConnectionEnvironment?
        var name: String = ""
        var status: Int = 0
        var percentDone: Double = 0.0
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
        var isLoading: Bool = false
        var errorMessage: String?
        @Presents var alert: AlertState<AlertAction>?
        @Presents var removeConfirmation: ConfirmationDialogState<RemoveConfirmationAction>?

        init(
            torrentID: Torrent.Identifier,
            connectionEnvironment: ServerConnectionEnvironment? = nil,
            name: String = "",
            status: Int = 0,
            percentDone: Double = 0.0,
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
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.torrentID = torrentID
            self.connectionEnvironment = connectionEnvironment
            self.name = name
            self.status = status
            self.percentDone = percentDone
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
            self.isLoading = isLoading
            self.errorMessage = errorMessage
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
        }

        @available(*, deprecated, message: "Use torrentID overload")
        init(
            torrentId: Int,
            connectionEnvironment: ServerConnectionEnvironment? = nil,
            name: String = "",
            status: Int = 0,
            percentDone: Double = 0.0,
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
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.init(
                torrentID: .init(rawValue: torrentId),
                connectionEnvironment: connectionEnvironment,
                name: name,
                status: status,
                percentDone: percentDone,
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
                isLoading: isLoading,
                errorMessage: errorMessage
            )
        }

        func isCommandCategoryLocked(_ category: TorrentDetailReducer.CommandCategory) -> Bool {
            if let activeCommand, activeCommand.category == category {
                return true
            }
            return pendingCommands.contains(where: { $0.category == category })
        }
    }
}
