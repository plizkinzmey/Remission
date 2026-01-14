import ComposableArchitecture
import Foundation

// swiftlint:disable type_body_length

@Reducer
struct TorrentDetailReducer {
    enum Action: Equatable {
        case task
        case teardown
        case refreshRequested
        case detailsResponse(TaskResult<DetailsResponse>)
        case commandResponse(CommandResult)
        case startTapped
        case pauseTapped
        case verifyTapped
        case removeButtonTapped
        case removeConfirmation(PresentationAction<RemoveConfirmationAction>)
        case priorityChanged(fileIndices: [Int], priority: Int)
        case toggleDownloadLimit(Bool)
        case toggleUploadLimit(Bool)
        case downloadLimitChanged(Int)
        case uploadLimitChanged(Int)
        case commandDidFinish(String)
        case commandFailed(String)
        case dismissError
        case errorPresenter(ErrorPresenter<ErrorRetry>.Action)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    struct DetailsResponse: Equatable {
        var torrent: Torrent
        var timestamp: Date
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum RemoveConfirmationAction: Equatable {
        case deleteTorrentOnly
        case deleteWithData
        case cancel
    }

    enum Delegate: Equatable {
        case closeRequested
        case torrentUpdated(Torrent)
        case torrentRemoved(Torrent.Identifier)
    }

    enum CommandCategory: Equatable {
        case start
        case pause
        case verify
        case remove
        case priority
    }

    enum CommandKind: Equatable {
        case start
        case pause
        case verify
        case remove(deleteData: Bool)
        case priority(indices: [Int], priority: TorrentRepository.FilePriority)

        var category: CommandCategory {
            switch self {
            case .start:
                return .start
            case .pause:
                return .pause
            case .verify:
                return .verify
            case .remove:
                return .remove
            case .priority:
                return .priority
            }
        }
    }

    enum CommandResult: Equatable {
        case success(CommandKind)
        case failure(CommandKind, String)
    }

    enum ErrorRetry: Equatable {
        case reloadDetails
        case command(CommandKind)
    }

    @Dependency(\.dateProvider) var dateProvider

    private enum FetchTrigger {
        case initial
        case manual
    }

    private enum CancelID: Hashable {
        case loadTorrentDetails
        case commandExecution
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return loadDetails(state: &state, trigger: .initial)

            case .refreshRequested:
                return loadDetails(state: &state, trigger: .manual)

            case .teardown:
                state.isLoading = false
                state.pendingCommands.removeAll()
                state.activeCommand = nil
                state.pendingListSync = false
                return .merge(
                    .cancel(id: CancelID.loadTorrentDetails),
                    .cancel(id: CancelID.commandExecution)
                )

            case .detailsResponse(.success(let response)):
                state.isLoading = false
                state.errorPresenter.banner = nil
                state.apply(response.torrent)
                state.speedHistory.append(
                    timestamp: response.timestamp,
                    downloadRate: state.rateDownload,
                    uploadRate: state.rateUpload
                )
                if state.pendingListSync {
                    state.pendingListSync = false
                    return .send(.delegate(.torrentUpdated(response.torrent)))
                }
                return .none

            case .detailsResponse(.failure(let error)):
                state.isLoading = false
                let message = Self.describe(error)
                state.errorPresenter.banner = .init(
                    message: message,
                    retry: .reloadDetails
                )
                state.pendingListSync = false
                return .none

            case .commandResponse(.success(let command)):
                state.activeCommand = nil
                if Self.shouldSyncList(after: command) {
                    state.pendingListSync = true
                }
                let torrentID = state.torrentID
                let next = startNextCommand(state: &state)
                return .merge(
                    commandSuccessEffect(for: command, torrentID: torrentID),
                    next
                )

            case .commandResponse(.failure(_, let message)):
                state.activeCommand = nil
                state.pendingListSync = false
                let next = startNextCommand(state: &state)
                return .merge(.send(.commandFailed(message)), next)

            case .startTapped:
                return enqueueCommand(.start, state: &state)

            case .pauseTapped:
                return enqueueCommand(.pause, state: &state)

            case .verifyTapped:
                return enqueueCommand(.verify, state: &state)

            case .removeButtonTapped:
                state.removeConfirmation = .removeTorrent(name: state.name)
                return .none

            case .removeConfirmation(.presented(.deleteTorrentOnly)):
                state.removeConfirmation = nil
                return enqueueCommand(.remove(deleteData: false), state: &state)

            case .removeConfirmation(.presented(.deleteWithData)):
                state.removeConfirmation = nil
                return enqueueCommand(.remove(deleteData: true), state: &state)

            case .removeConfirmation(.presented(.cancel)):
                state.removeConfirmation = nil
                return .none

            case .removeConfirmation:
                return .none

            case .priorityChanged(let fileIndices, let priority):
                guard fileIndices.isEmpty == false else {
                    return .none
                }
                guard let mappedPriority = Self.filePriority(from: priority) else {
                    return .none
                }
                for index in fileIndices {
                    if var file = state.files[id: index] {
                        file.priority = mappedPriority.rawValue
                        state.files[id: index] = file
                    }
                }
                return enqueueCommand(
                    .priority(indices: fileIndices, priority: mappedPriority),
                    state: &state
                )

            case .toggleDownloadLimit(let isEnabled):
                state.downloadLimited = isEnabled
                return updateTransferSettings(
                    state: &state,
                    limit: .download(
                        .init(isEnabled: isEnabled, kilobytesPerSecond: state.downloadLimit)
                    )
                )

            case .toggleUploadLimit(let isEnabled):
                state.uploadLimited = isEnabled
                return updateTransferSettings(
                    state: &state,
                    limit: .upload(
                        .init(isEnabled: isEnabled, kilobytesPerSecond: state.uploadLimit)
                    )
                )

            case .downloadLimitChanged(let limit):
                let bounded = max(0, limit)
                state.downloadLimit = bounded
                guard state.downloadLimited else { return .none }
                return updateTransferSettings(
                    state: &state,
                    limit: .download(.init(isEnabled: true, kilobytesPerSecond: bounded))
                )

            case .uploadLimitChanged(let limit):
                let bounded = max(0, limit)
                state.uploadLimit = bounded
                guard state.uploadLimited else { return .none }
                return updateTransferSettings(
                    state: &state,
                    limit: .upload(.init(isEnabled: true, kilobytesPerSecond: bounded))
                )

            case .commandDidFinish(let message):
                state.alert = .info(message: message)
                // Always trigger a refresh after any command so the tests (and UI)
                // observe a `.detailsResponse` with fresh data without user input.
                return .send(.refreshRequested)

            case .commandFailed(let message):
                state.alert = .error(message: message)
                return .none

            case .dismissError:
                state.errorPresenter.banner = nil
                return .none

            case .errorPresenter(.retryRequested(.reloadDetails)):
                return .send(.refreshRequested)

            case .errorPresenter(.retryRequested(.command(let command))):
                return enqueueCommand(command, state: &state)

            case .errorPresenter:
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$removeConfirmation, action: \.removeConfirmation)
        Scope(state: \.errorPresenter, action: \.errorPresenter) {
            ErrorPresenter<ErrorRetry>()
        }
    }

    private func loadDetails(
        state: inout State,
        trigger: FetchTrigger
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.isLoading = false
            state.errorPresenter.banner = .init(
                message: L10n.tr("torrentDetail.error.noConnection"),
                retry: nil
            )
            return .none
        }

        switch trigger {
        case .initial:
            state.isLoading = true
        case .manual:
            state.isLoading = true
        }

        state.errorPresenter.banner = nil
        let torrentID = state.torrentID
        return .run { send in
            await send(
                .detailsResponse(
                    TaskResult {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.torrentRepository) var repository: TorrentRepository
                            let torrent = try await repository.fetchDetails(torrentID)
                            return DetailsResponse(
                                torrent: torrent,
                                timestamp: dateProvider.now()
                            )
                        }
                    }
                )
            )
        }
        .cancellable(id: CancelID.loadTorrentDetails, cancelInFlight: true)
    }

    private func enqueueCommand(
        _ command: CommandKind,
        state: inout State
    ) -> Effect<Action> {
        guard state.connectionEnvironment != nil else {
            state.alert = .connectionMissing()
            return .none
        }

        state.pendingCommands.append(command)
        return startNextCommand(state: &state)
    }

    private func startNextCommand(
        state: inout State
    ) -> Effect<Action> {
        guard state.activeCommand == nil,
            let next = state.pendingCommands.first
        else {
            return .none
        }

        state.pendingCommands.removeFirst()
        state.activeCommand = next
        return execute(command: next, state: &state)
    }

    private func execute(
        command: CommandKind,
        state: inout State
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            return .send(
                .commandResponse(
                    .failure(command, L10n.tr("torrentDetail.error.noConnection"))
                )
            )
        }

        let torrentID = state.torrentID
        return .run { send in
            let result = await TaskResult {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    try await perform(
                        command: command,
                        repository: repository,
                        torrentID: torrentID
                    )
                }
            }

            switch result {
            case .success:
                await send(.commandResponse(.success(command)))
            case .failure(let error):
                await send(.commandResponse(.failure(command, Self.describe(error))))
            }
        }
        .cancellable(id: CancelID.commandExecution, cancelInFlight: true)
    }

    private func perform(
        command: CommandKind,
        repository: TorrentRepository,
        torrentID: Torrent.Identifier
    ) async throws {
        switch command {
        case .start:
            try await repository.start([torrentID])
        case .pause:
            try await repository.stop([torrentID])
        case .verify:
            try await repository.verify([torrentID])
        case .remove(let deleteData):
            try await repository.remove([torrentID], deleteLocalData: deleteData)
        case .priority(let indices, let priority):
            let updates = indices.map {
                TorrentRepository.FileSelectionUpdate(
                    fileIndex: $0,
                    priority: priority
                )
            }
            try await repository.updateFileSelection(updates, in: torrentID)
        }
    }

    private func commandSuccessEffect(
        for command: CommandKind,
        torrentID: Torrent.Identifier
    ) -> Effect<Action> {
        switch command {
        case .start:
            return .send(.commandDidFinish(L10n.tr("torrentDetail.status.started")))
        case .pause:
            return .send(.commandDidFinish(L10n.tr("torrentDetail.status.stopped")))
        case .verify:
            return .send(.commandDidFinish(L10n.tr("torrentDetail.status.verify")))
        case .priority:
            return .send(.refreshRequested)
        case .remove:
            return .send(.delegate(.torrentRemoved(torrentID)))
        }
    }

    private enum TransferLimitUpdate {
        case download(TorrentRepository.TransferLimit)
        case upload(TorrentRepository.TransferLimit)
    }

    private func updateTransferSettings(
        state: inout State,
        limit: TransferLimitUpdate
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.alert = .connectionMissing()
            return .none
        }

        let torrentID = state.torrentID
        return .run { send in
            let result = await TaskResult {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    switch limit {
                    case .download(let transfer):
                        try await repository.updateTransferSettings(
                            .init(downloadLimit: transfer),
                            for: [torrentID]
                        )
                    case .upload(let transfer):
                        try await repository.updateTransferSettings(
                            .init(uploadLimit: transfer),
                            for: [torrentID]
                        )
                    }
                }
            }

            switch result {
            case .success:
                await send(.refreshRequested)
            case .failure(let error):
                await send(.commandFailed(Self.describe(error)))
            }
        }
    }

    private static func filePriority(from priority: Int) -> TorrentRepository.FilePriority? {
        switch priority {
        case -1: return .low
        case 0: return .normal
        case 1: return .high
        default: return nil
        }
    }

    private static func describe(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userFriendlyMessage
        }
        if let parserError = error as? TorrentDetailParserError {
            return parserError.localizedDescription
        }
        return error.localizedDescription
    }

    private static func shouldSyncList(after command: CommandKind) -> Bool {
        switch command {
        case .start, .pause, .verify, .priority:
            return true
        case .remove:
            return false
        }
    }
}

// MARK: - Reducer helpers

extension TorrentDetailReducer.State {
    mutating func apply(_ torrent: Torrent) {
        torrentID = torrent.id
        name = torrent.name
        status = torrent.status.rawValue
        tags = torrent.tags
        percentDone = torrent.summary.progress.percentDone
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
    }
}

// swiftlint:enable type_body_length
