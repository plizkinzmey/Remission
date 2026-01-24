import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    func importReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .fileImportResult(.success(let url)):
            state.addTorrent = AddTorrentReducer.State(
                pendingInput: PendingTorrentInput(
                    payload: .torrentFile(data: Data(), fileName: url.lastPathComponent),
                    sourceDescription: url.lastPathComponent
                ),
                connectionEnvironment: state.connectionEnvironment,
                serverID: state.server.id
            )
            return .send(.addTorrent(.presented(.fileImportResult(.success(url)))))

        case .fileImportResult(.failure):
            return .none

        case .fileImportLoaded:
            return .none

        default:
            return .none
        }
    }
}
