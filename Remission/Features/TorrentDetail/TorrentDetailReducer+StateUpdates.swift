import ComposableArchitecture
import Foundation

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
        peers.peers = IdentifiedArray(uniqueElements: torrent.summary.peers.sources)

        if let details = torrent.details {
            hasLoadedMetadata = true
            downloadDir = details.downloadDirectory
            if let addedDate = details.addedDate {
                dateAdded = Int(addedDate.timeIntervalSince1970)
            } else {
                dateAdded = 0
            }
            files.files = IdentifiedArray(uniqueElements: details.files)
            trackers.trackers = IdentifiedArray(uniqueElements: details.trackers)
            trackers.trackerStats = IdentifiedArray(uniqueElements: details.trackerStats)
        } else {
            hasLoadedMetadata = false
            downloadDir = ""
            dateAdded = 0
            files.files = []
            trackers.trackers = []
            trackers.trackerStats = []
        }

        if let pendingStatusChange {
            switch pendingStatusChange.command.category {
            case .verify:
                if status == Torrent.Status.checkWaiting.rawValue
                    || status == Torrent.Status.checking.rawValue
                {
                    self.pendingStatusChange = nil
                }

            default:
                if pendingStatusChange.initialStatus != status {
                    self.pendingStatusChange = nil
                }
            }
        }

        // Update sub-state transfer limits
        transferLimits.downloadLimit = downloadLimit
        transferLimits.downloadLimited = downloadLimited
        transferLimits.uploadLimit = uploadLimit
        transferLimits.uploadLimited = uploadLimited

        // Update category sub-state
        categoryState.category = TorrentCategory.category(from: tags)
        categoryState.tags = tags
        categoryState.lastSyncedTags = tags

        // Update stats
        stats.rateDownload = rateDownload
        stats.rateUpload = rateUpload
        stats.uploadRatio = uploadRatio
        stats.downloadedEver = downloadedEver
        stats.uploadedEver = uploadedEver
        stats.totalSize = totalSize
        stats.percentDone = percentDone
        stats.eta = eta
    }
}
