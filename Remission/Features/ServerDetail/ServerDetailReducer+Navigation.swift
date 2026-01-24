import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func navigationReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .settingsButtonTapped:
            state.settings = SettingsReducer.State(
                serverID: state.server.id,
                serverName: state.server.name,
                connectionEnvironment: state.connectionEnvironment
            )
            return .none

        case .diagnosticsButtonTapped:
            state.diagnostics = DiagnosticsReducer.State()
            return .none

        case .settings(.presented(.delegate(.pollingIntervalChanged))):
            return .send(.torrentList(.refreshRequested))

        case .settings(.presented(.delegate(.closeRequested))):
            state.settings = nil
            return .none

        case .settings:
            return .none

        case .diagnostics(.presented(.delegate(.closeRequested))):
            state.diagnostics = nil
            return .none

        case .diagnostics:
            return .none

        case .torrentDetail(.presented(.delegate(.removeRequested(let id, _)))):
            return .send(.torrentList(.removeTapped(id)))

        case .torrentDetail(.presented(.delegate(.closeRequested))):
            state.torrentDetail = nil
            return .none

        case .torrentDetail:
            return .none

        case .addTorrent(.presented(.delegate(.closeRequested))):
            state.addTorrent = nil
            return .none

        case .addTorrent:
            return .none

        case .torrentList(.rowTapped(let id)):
            if let item = state.torrentList.items[id: id] {
                state.torrentDetail = TorrentDetailReducer.State(
                    torrentID: id,
                    torrent: item.torrent,
                    connectionEnvironment: state.connectionEnvironment
                )
            }
            return .none

        case .torrentList(.addTorrentButtonTapped):
            state.addTorrent = AddTorrentReducer.State(
                connectionEnvironment: state.connectionEnvironment,
                serverID: state.server.id
            )
            return .none

        case .torrentList:
            return .none

        case .delegate:
            return .none

        default:
            return .none
        }
    }
}
