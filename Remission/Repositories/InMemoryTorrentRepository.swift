import Foundation

// MARK: - Torrent Repository (In-Memory)

/// Хранилище для in-memory реализации `TorrentRepository`.
actor InMemoryTorrentRepositoryStore {
    enum Operation: Hashable {
        case fetchList
        case fetchDetails
        case add
        case start
        case stop
        case remove
        case verify
        case updateTransferSettings
        case updateLabels
        case updateFileSelection
    }

    private(set) var torrents: [Torrent]
    private let failureTracker = InMemoryFailureTracker<Operation>()

    init(torrents: [Torrent] = []) {
        self.torrents = torrents
    }

    func setTorrents(_ torrents: [Torrent]) {
        self.torrents = torrents
    }

    func markFailure(_ operation: Operation) async {
        await failureTracker.markFailure(operation)
    }

    func clearFailure(_ operation: Operation) async {
        await failureTracker.clearFailure(operation)
    }

    func resetFailures() async {
        await failureTracker.resetFailures()
    }

    func shouldFail(_ operation: Operation) async -> Bool {
        await failureTracker.shouldFail(operation)
    }
}

extension InMemoryTorrentRepositoryStore {
    func snapshot() -> [Torrent] {
        torrents
    }

    func withTorrents<Result>(
        _ operation: Operation,
        _ action: (inout [Torrent]) throws -> Result
    ) async throws -> Result {
        if await shouldFail(operation) {
            throw InMemoryTorrentRepositoryError.operationFailed(operation)
        }
        return try action(&torrents)
    }
}

enum InMemoryTorrentRepositoryError: Error, LocalizedError, Sendable {
    case operationFailed(InMemoryTorrentRepositoryStore.Operation)
    case torrentNotFound(Torrent.Identifier)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "InMemoryTorrentRepository operation \(operation) marked as failed."
        case .torrentNotFound(let identifier):
            return "Torrent with id \(identifier.rawValue) not found in in-memory store."
        }
    }
}

private typealias TorrentTransferUpdateHandler =
    @Sendable (TorrentRepository.TransferSettings, [Torrent.Identifier]) async throws -> Void
private typealias TorrentLabelsUpdateHandler =
    @Sendable ([String], [Torrent.Identifier]) async throws -> Void
private typealias TorrentFileSelectionHandler =
    @Sendable ([TorrentRepository.FileSelectionUpdate], Torrent.Identifier) async throws -> Void

extension TorrentRepository {
    /// Возвращает in-memory реализацию, используемую в превью и тестах.
    static func inMemory(
        store: InMemoryTorrentRepositoryStore
    ) -> TorrentRepository {
        TorrentRepository(
            fetchList: makeFetchList(store: store),
            fetchDetails: makeFetchDetails(store: store),
            add: makeAdd(store: store),
            start: makeStart(store: store),
            stop: makeStop(store: store),
            remove: makeRemove(store: store),
            verify: makeVerify(store: store),
            updateTransferSettings: makeUpdateTransferSettings(store: store),
            updateLabels: makeUpdateLabels(store: store),
            updateFileSelection: makeUpdateFileSelection(store: store)
        )
    }

    private static func makeFetchList(
        store: InMemoryTorrentRepositoryStore
    ) -> @Sendable () async throws -> [Torrent] {
        {
            try await store.withTorrents(.fetchList) { torrents in
                torrents
            }
        }
    }

    private static func makeFetchDetails(
        store: InMemoryTorrentRepositoryStore
    ) -> @Sendable (Torrent.Identifier) async throws -> Torrent {
        { identifier in
            try await store.withTorrents(.fetchDetails) { torrents in
                guard let torrent = torrents.first(where: { $0.id == identifier }) else {
                    throw InMemoryTorrentRepositoryError.torrentNotFound(identifier)
                }
                return torrent
            }
        }
    }

    // swiftlint:disable opening_brace
    private static func makeAdd(
        store: InMemoryTorrentRepositoryStore
    )
        -> @Sendable (PendingTorrentInput, String, Bool, [String]?) async throws ->
        TorrentRepository.AddResult
    {
        { input, destination, startPaused, labels in
            try await store.withTorrents(.add) { torrents in
                let nextIDValue: Int = (torrents.map(\.id.rawValue).max() ?? 0) + 1
                let addedID = Torrent.Identifier(rawValue: nextIDValue)
                let addedName = input.displayName
                let addedHash = UUID().uuidString

                var newTorrent = torrents.first ?? .previewDownloading
                newTorrent.id = addedID
                newTorrent.name = addedName
                newTorrent.details?.downloadDirectory = destination
                newTorrent.summary.progress.percentDone =
                    startPaused ? 0.0 : newTorrent.summary.progress.percentDone
                newTorrent.summary.peers = Torrent.Peers(connected: 0, sources: [])
                newTorrent.summary.transfer.downloadRate = 0
                newTorrent.summary.transfer.uploadRate = 0
                newTorrent.details?.trackers = []
                newTorrent.details?.trackerStats = []
                newTorrent.details?.files = []
                newTorrent.tags = labels ?? []

                if startPaused {
                    newTorrent.status = .stopped
                }

                torrents.append(newTorrent)

                return TorrentRepository.AddResult(
                    status: .added,
                    id: addedID,
                    name: addedName,
                    hashString: addedHash
                )
            }
        }
    }
    // swiftlint:enable opening_brace

    private static func makeStart(
        store: InMemoryTorrentRepositoryStore
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        { ids in
            try await store.withTorrents(.start) { torrents in
                for index in torrents.indices where ids.contains(torrents[index].id) {
                    torrents[index].status = .downloading
                }
            }
        }
    }

    private static func makeStop(
        store: InMemoryTorrentRepositoryStore
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        { ids in
            try await store.withTorrents(.stop) { torrents in
                for index in torrents.indices where ids.contains(torrents[index].id) {
                    torrents[index].status = .stopped
                }
            }
        }
    }

    private static func makeRemove(
        store: InMemoryTorrentRepositoryStore
    ) -> @Sendable ([Torrent.Identifier], Bool?) async throws -> Void {
        { ids, _ in
            try await store.withTorrents(.remove) { torrents in
                torrents.removeAll(where: { ids.contains($0.id) })
            }
        }
    }

    private static func makeVerify(
        store: InMemoryTorrentRepositoryStore
    ) -> @Sendable ([Torrent.Identifier]) async throws -> Void {
        { ids in
            try await store.withTorrents(.verify) { torrents in
                for index in torrents.indices where ids.contains(torrents[index].id) {
                    torrents[index].status = .checking
                }
            }
        }
    }

    private static func makeUpdateTransferSettings(
        store: InMemoryTorrentRepositoryStore
    ) -> TorrentTransferUpdateHandler {
        { settings, ids in
            try await store.withTorrents(.updateTransferSettings) { torrents in
                for index in torrents.indices where ids.contains(torrents[index].id) {
                    if let downloadLimit = settings.downloadLimit {
                        torrents[index].summary.transfer.downloadLimit = .init(
                            isEnabled: downloadLimit.isEnabled,
                            kilobytesPerSecond: downloadLimit.kilobytesPerSecond
                        )
                    }
                    if let uploadLimit = settings.uploadLimit {
                        torrents[index].summary.transfer.uploadLimit = .init(
                            isEnabled: uploadLimit.isEnabled,
                            kilobytesPerSecond: uploadLimit.kilobytesPerSecond
                        )
                    }
                }
            }
        }
    }

    private static func makeUpdateLabels(
        store: InMemoryTorrentRepositoryStore
    ) -> TorrentLabelsUpdateHandler {
        { labels, ids in
            try await store.withTorrents(.updateLabels) { torrents in
                for index in torrents.indices where ids.contains(torrents[index].id) {
                    torrents[index].tags = labels
                }
            }
        }
    }

    private static func makeUpdateFileSelection(
        store: InMemoryTorrentRepositoryStore
    ) -> TorrentFileSelectionHandler {
        { updates, torrentID in
            try await store.withTorrents(.updateFileSelection) { torrents in
                guard
                    let index = torrents.firstIndex(where: { $0.id == torrentID }),
                    var details = torrents[index].details
                else {
                    return
                }

                for update in updates {
                    guard details.files.indices.contains(update.fileIndex) else {
                        continue
                    }
                    if let isWanted = update.isWanted {
                        details.files[update.fileIndex].wanted = isWanted
                    }
                    if let priorityRaw = update.priority?.rawValue {
                        details.files[update.fileIndex].priority = priorityRaw
                    }
                }
                torrents[index].details = details
            }
        }
    }
}
