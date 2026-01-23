import ComposableArchitecture
import Foundation

extension TorrentDetailReducer {
    func loadDetails(
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

    func enqueueCommand(
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

    func startNextCommand(
        state: inout State
    ) -> Effect<Action> {
        guard state.activeCommand == nil,
            let next = state.pendingCommands.first
        else {
            return .none
        }

        state.pendingCommands.removeFirst()
        state.activeCommand = next
        if shouldWaitForStatusChange(next) {
            state.pendingStatusChange = .init(
                command: next,
                initialStatus: state.status
            )
        }
        return execute(command: next, state: &state)
    }

    func execute(
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

    func perform(
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

    func commandSuccessEffect(
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

    enum TransferLimitUpdate {
        case download(TorrentRepository.TransferLimit)
        case upload(TorrentRepository.TransferLimit)
    }

    func updateTransferSettings(
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

    func updateCategory(
        state: inout State
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.alert = .connectionMissing()
            return .none
        }

        let torrentID = state.torrentID
        let labels = state.tags
        return .run { send in
            let result = await Result {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    try await repository.updateLabels(labels, for: [torrentID])
                }
            }

            let mapped: CategoryUpdateResult
            switch result {
            case .success:
                mapped = .success
            case .failure(let error):
                mapped = .failure(Self.describe(error))
            }

            await send(.categoryUpdateResponse(mapped))
        }
    }

    static func filePriority(from priority: Int) -> TorrentRepository.FilePriority? {
        switch priority {
        case -1: return .low
        case 0: return .normal
        case 1: return .high
        default: return nil
        }
    }

    static func describe(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userFacingMessage
        }
        if let parserError = error as? TorrentDetailParserError {
            return parserError.localizedDescription
        }
        return error.localizedDescription
    }

    static func shouldSyncList(after command: CommandKind) -> Bool {
        switch command {
        case .start, .pause, .verify, .priority:
            return true
        case .remove:
            return false
        }
    }

    private func shouldWaitForStatusChange(_ command: CommandKind) -> Bool {
        switch command {
        case .start, .pause, .verify:
            return true
        case .remove, .priority:
            return false
        }
    }
}
