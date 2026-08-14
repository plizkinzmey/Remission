import ComposableArchitecture
import Foundation

extension TorrentDetailReducer {
    func updateTransferSettings(
        state: inout State,
        limit: TransferLimitUpdate
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.alert = AlertState<TorrentDetailReducer.AlertAction>.connectionMissing()
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
                await send(.commandFailed(error.userFacingMessage))
            }
        }
    }

    func updateCategory(
        state: inout State,
        category: TorrentCategory
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.alert = AlertState<TorrentDetailReducer.AlertAction>.connectionMissing()
            return .none
        }

        let torrentID = state.torrentID
        let labels = state.categoryState.tags
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
                mapped = .failure(error.userFacingMessage)
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

    static func shouldSyncList(after command: CommandKind) -> Bool {
        switch command {
        case .start, .pause, .verify, .priority:
            return true
        case .remove:
            return false
        }
    }

    static func shouldWaitForStatusChange(_ command: CommandKind) -> Bool {
        switch command {
        case .start, .pause, .verify:
            return true
        case .remove, .priority:
            return false
        }
    }
}

extension TorrentDetailReducer.State {
}
