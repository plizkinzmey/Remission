import ComposableArchitecture
import Foundation

extension ServerListReducer {
    func storageReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .storageRequested(let id):
            guard let server = state.servers[id: id] else { return .none }
            if state.connectionStatuses[id]?.isLoadingStorage == true {
                return .none
            }
            if state.connectionStatuses[id]?.storageSummary != nil {
                return .none
            }
            state.connectionStatuses[id]?.isLoadingStorage = true
            return .run { [server] send in
                do {
                    let environment = try await serverConnectionEnvironmentFactory.make(server)
                    let session = try await environment.withDependencies {
                        @Dependency(\.sessionRepository) var sessionRepository: SessionRepository
                        return try await sessionRepository.fetchState()
                    }
                    let torrents = try await environment.withDependencies {
                        @Dependency(\.torrentRepository) var torrentRepository: TorrentRepository
                        return try await torrentRepository.fetchList()
                    }
                    let snapshot = try? await environment.snapshot.load()
                    if let summary = StorageSummary.calculate(
                        torrents: torrents,
                        session: session,
                        updatedAt: snapshot?.latestUpdatedAt
                    ) {
                        await send(.storageResponse(id, .success(summary)))
                    }
                } catch {
                    await send(.storageResponse(id, .failure(error)))
                }
            }
            .cancellable(id: ConnectionCancellationID.storage(id), cancelInFlight: true)

        case .storageResponse(let id, .success(let summary)):
            state.connectionStatuses[id]?.storageSummary = summary
            state.connectionStatuses[id]?.isLoadingStorage = false
            return .none

        case .storageResponse(let id, .failure):
            if state.connectionStatuses[id]?.storageSummary != nil {
                return .none
            }
            state.connectionStatuses[id]?.isLoadingStorage = false
            return .none

        default:
            return .none
        }
    }
}
