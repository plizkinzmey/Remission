import ComposableArchitecture
import Foundation

extension TorrentDetailReducer {
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        // Core identifiers
        var torrentID: Torrent.Identifier
        var connectionEnvironment: ServerConnectionEnvironment?

        // Basic torrent info
        var name: String = ""
        var status: Int = 0
        var tags: [String] = []
        var category: TorrentCategory = .other
        var lastSyncedTags: [String] = []

        // Progress
        var percentDone: Double = 0.0
        var recheckProgress: Double = 0.0
        var totalSize: Int = 0
        var downloadedEver: Int = 0
        var uploadedEver: Int = 0
        var eta: Int = 0

        // Transfer rates
        var rateDownload: Int = 0
        var rateUpload: Int = 0
        var uploadRatio: Double = 0.0

        // Transfer limits
        var downloadLimit: Int = 0
        var downloadLimited: Bool = false
        var uploadLimit: Int = 0
        var uploadLimited: Bool = false

        // Sub-states
        var files = TorrentFilesReducer.State()
        var peers = TorrentPeersReducer.State()
        var trackers = TorrentTrackersReducer.State()
        var stats = TorrentStatsReducer.State()
        var commands = TorrentCommandsReducer.State()
        var transferLimits = TorrentTransferLimitsReducer.State()
        var categoryState = TorrentCategoryReducer.State()

        // UI state
        var speedHistory: TorrentDetailSpeedHistory = .init()
        var peersConnected: Int = 0
        var downloadDir: String = ""
        var dateAdded: Int = 0
        var hasLoadedMetadata: Bool = false
        var pendingStatusChange: TorrentDetailPendingStatusChange?
        var isLoading: Bool = false
        var errorPresenter: ErrorPresenter<ErrorRetry>.State = .init()
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

        mutating func applyConnectionEnvironment(_ environment: ServerConnectionEnvironment?) {
            connectionEnvironment = environment
            guard environment == nil else { return }
            commands = .init()
        }

        // Computed lock properties
        var isStartLocked: Bool { isCommandCategoryLocked(.start) }
        var isPauseLocked: Bool { isCommandCategoryLocked(.pause) }
        var isVerifyLocked: Bool { isCommandCategoryLocked(.verify) }
        var isRemoveLocked: Bool { isCommandCategoryLocked(.remove) }
        var isPriorityLocked: Bool { isCommandCategoryLocked(.priority) }

        func isCommandCategoryLocked(_ category: CommandCategory) -> Bool {
            if let activeCommand = commands.activeCommand, activeCommand.category == category {
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
            return commands.pendingCommands.contains(where: { $0.category == category })
        }
    }

}
