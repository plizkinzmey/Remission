import ComposableArchitecture
import Foundation

extension TorrentDetailReducer {
    // MARK: - Helpers
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
            state.alert = AlertState<TorrentDetailReducer.AlertAction>.connectionMissing()
            return .none
        }

        state.commands.pendingCommands.append(command)
        return startNextCommand(state: &state)
    }

    func startNextCommand(
        state: inout State
    ) -> Effect<Action> {
        guard state.commands.activeCommand == nil,
            let next = state.commands.pendingCommands.first
        else {
            return .none
        }

        state.commands.pendingCommands.removeFirst()
        state.commands.activeCommand = next
        if Self.shouldWaitForStatusChange(next) {
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
                await send(.commandResponse(.failure(command, error.userFacingMessage)))
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

}
