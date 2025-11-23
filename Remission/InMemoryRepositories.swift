import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
#endif

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
        case updateFileSelection
    }

    private(set) var torrents: [Torrent]
    private var failedOperations: Set<Operation> = []

    init(torrents: [Torrent] = []) {
        self.torrents = torrents
    }

    func setTorrents(_ torrents: [Torrent]) {
        self.torrents = torrents
    }

    func markFailure(_ operation: Operation) {
        failedOperations.insert(operation)
    }

    func clearFailure(_ operation: Operation) {
        failedOperations.remove(operation)
    }

    func resetFailures() {
        failedOperations.removeAll()
    }

    func shouldFail(_ operation: Operation) -> Bool {
        failedOperations.contains(operation)
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
        if shouldFail(operation) {
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
        { input, destination, startPaused, _ in
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

// MARK: - Session Repository (In-Memory)

actor InMemorySessionRepositoryStore {
    enum Operation: Hashable {
        case performHandshake
        case fetchState
        case updateState
        case checkCompatibility
    }

    private(set) var handshake: SessionRepository.Handshake
    private(set) var state: SessionState
    private(set) var compatibility: SessionRepository.Compatibility
    private var failedOperations: Set<Operation> = []

    init(
        handshake: SessionRepository.Handshake,
        state: SessionState,
        compatibility: SessionRepository.Compatibility
    ) {
        self.handshake = handshake
        self.state = state
        self.compatibility = compatibility
    }

    func setState(_ state: SessionState) {
        self.state = state
    }

    func setHandshake(_ handshake: SessionRepository.Handshake) {
        self.handshake = handshake
    }

    func setCompatibility(_ compatibility: SessionRepository.Compatibility) {
        self.compatibility = compatibility
    }

    func markFailure(_ operation: Operation) {
        failedOperations.insert(operation)
    }

    func clearFailure(_ operation: Operation) {
        failedOperations.remove(operation)
    }

    func shouldFail(_ operation: Operation) -> Bool {
        failedOperations.contains(operation)
    }
}

enum InMemorySessionRepositoryError: Error, LocalizedError, Sendable {
    case operationFailed(InMemorySessionRepositoryStore.Operation)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "InMemorySessionRepository operation \(operation) marked as failed."
        }
    }
}

extension SessionRepository {
    static func inMemory(
        store: InMemorySessionRepositoryStore
    ) -> SessionRepository {
        SessionRepository(
            performHandshake: {
                if await store.shouldFail(.performHandshake) {
                    throw InMemorySessionRepositoryError.operationFailed(.performHandshake)
                }
                return await store.handshake
            },
            fetchState: {
                if await store.shouldFail(.fetchState) {
                    throw InMemorySessionRepositoryError.operationFailed(.fetchState)
                }
                return await store.state
            },
            updateState: { update in
                if await store.shouldFail(.updateState) {
                    throw InMemorySessionRepositoryError.operationFailed(.updateState)
                }
                let newState = await store.apply(update: update)
                await store.setState(newState)
                return await store.state
            },
            checkCompatibility: {
                if await store.shouldFail(.checkCompatibility) {
                    throw InMemorySessionRepositoryError.operationFailed(.checkCompatibility)
                }
                return await store.compatibility
            }
        )
    }
}

extension InMemorySessionRepositoryStore {
    fileprivate func apply(update: SessionRepository.SessionUpdate) -> SessionState {
        var newState: SessionState = state
        if let speedLimits = update.speedLimits {
            if let download = speedLimits.download {
                newState.speedLimits.download = .init(
                    isEnabled: download.isEnabled,
                    kilobytesPerSecond: download.kilobytesPerSecond
                )
            }
            if let upload = speedLimits.upload {
                newState.speedLimits.upload = .init(
                    isEnabled: upload.isEnabled,
                    kilobytesPerSecond: upload.kilobytesPerSecond
                )
            }
            if let alternative = speedLimits.alternative {
                newState.speedLimits.alternative = .init(
                    isEnabled: alternative.isEnabled,
                    downloadKilobytesPerSecond: alternative.downloadKilobytesPerSecond,
                    uploadKilobytesPerSecond: alternative.uploadKilobytesPerSecond
                )
            }
        }

        if let queue = update.queue {
            if let downloadLimit = queue.downloadLimit {
                newState.queue.downloadLimit = .init(
                    isEnabled: downloadLimit.isEnabled,
                    count: downloadLimit.count
                )
            }
            if let seedLimit = queue.seedLimit {
                newState.queue.seedLimit = .init(
                    isEnabled: seedLimit.isEnabled,
                    count: seedLimit.count
                )
            }
            if let considerStalled = queue.considerStalled {
                newState.queue.considerStalled = considerStalled
            }
            if let stalledMinutes = queue.stalledMinutes {
                newState.queue.stalledMinutes = stalledMinutes
            }
        }

        return newState
    }
}

// MARK: - User Preferences Repository (In-Memory)

actor InMemoryUserPreferencesRepositoryStore {
    enum Operation: Hashable {
        case load
        case updatePollingInterval
        case setAutoRefreshEnabled
        case setTelemetryEnabled
        case updateDefaultSpeedLimits
    }

    private(set) var preferences: UserPreferences
    private var failedOperations: Set<Operation> = []
    private var observers: [UUID: AsyncStream<UserPreferences>.Continuation] = [:]

    init(preferences: UserPreferences) {
        self.preferences = preferences
    }

    func markFailure(_ operation: Operation) {
        failedOperations.insert(operation)
    }

    func clearFailure(_ operation: Operation) {
        failedOperations.remove(operation)
    }

    func shouldFail(_ operation: Operation) -> Bool {
        failedOperations.contains(operation)
    }

    func addObserver(
        id: UUID,
        continuation: AsyncStream<UserPreferences>.Continuation
    ) {
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeObserver(id: id)
            }
        }
    }

    func notifyObservers() {
        let current = preferences
        for continuation in observers.values {
            continuation.yield(current)
        }
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }
}

enum InMemoryUserPreferencesRepositoryError: Error, LocalizedError, Sendable, Equatable {
    case operationFailed(InMemoryUserPreferencesRepositoryStore.Operation)

    var errorDescription: String? {
        switch self {
        case .operationFailed(let operation):
            return "InMemoryUserPreferencesRepository operation \(operation) marked as failed."
        }
    }
}

extension UserPreferencesRepository {
    static func inMemory(
        store: InMemoryUserPreferencesRepositoryStore
    ) -> UserPreferencesRepository {
        UserPreferencesRepository(
            load: {
                if await store.shouldFail(.load) {
                    throw InMemoryUserPreferencesRepositoryError.operationFailed(.load)
                }
                return await store.preferences
            },
            updatePollingInterval: { interval in
                if await store.shouldFail(.updatePollingInterval) {
                    throw InMemoryUserPreferencesRepositoryError.operationFailed(
                        .updatePollingInterval)
                }
                await store.update {
                    $0.pollingInterval = interval
                    $0.version = UserPreferences.currentVersion
                }
                await store.notifyObservers()
                return await store.preferences
            },
            setAutoRefreshEnabled: { isEnabled in
                if await store.shouldFail(.setAutoRefreshEnabled) {
                    throw InMemoryUserPreferencesRepositoryError.operationFailed(
                        .setAutoRefreshEnabled)
                }
                await store.update {
                    $0.isAutoRefreshEnabled = isEnabled
                    $0.version = UserPreferences.currentVersion
                }
                await store.notifyObservers()
                return await store.preferences
            },
            setTelemetryEnabled: { isEnabled in
                if await store.shouldFail(.setTelemetryEnabled) {
                    throw InMemoryUserPreferencesRepositoryError.operationFailed(
                        .setTelemetryEnabled)
                }
                await store.update {
                    $0.isTelemetryEnabled = isEnabled
                    $0.version = UserPreferences.currentVersion
                }
                await store.notifyObservers()
                return await store.preferences
            },
            updateDefaultSpeedLimits: { limits in
                if await store.shouldFail(.updateDefaultSpeedLimits) {
                    throw InMemoryUserPreferencesRepositoryError.operationFailed(
                        .updateDefaultSpeedLimits)
                }
                await store.update {
                    $0.defaultSpeedLimits = limits
                    $0.version = UserPreferences.currentVersion
                }
                await store.notifyObservers()
                return await store.preferences
            },
            observe: {
                AsyncStream { continuation in
                    let id = UUID()
                    Task {
                        await store.addObserver(id: id, continuation: continuation)
                    }
                }
            }
        )
    }
}

extension InMemoryUserPreferencesRepositoryStore {
    fileprivate func update(_ updateBlock: (inout UserPreferences) -> Void) {
        updateBlock(&preferences)
    }
}
