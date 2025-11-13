import ComposableArchitecture
import Foundation

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var version: AppStateVersion
        var serverList: ServerListReducer.State
        var path: StackState<ServerDetailReducer.State>

        init(
            version: AppStateVersion = .latest,
            serverList: ServerListReducer.State = .init(),
            path: StackState<ServerDetailReducer.State> = .init()
        ) {
            self.version = version
            self.serverList = serverList
            self.path = path
        }
    }

    enum Action: Equatable {
        case serverList(ServerListReducer.Action)
        case path(StackAction<ServerDetailReducer.State, ServerDetailReducer.Action>)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .serverList(.delegate(.serverSelected(let server))):
                state.path.append(ServerDetailReducer.State(server: server))
                return .none

            case .serverList(.delegate(.serverCreated(let server))):
                state.path.append(ServerDetailReducer.State(server: server))
                return .none

            case .serverList(.delegate(.serverEditRequested(let server))):
                state.path.append(ServerDetailReducer.State(server: server, startEditing: true))
                return .none

            case .serverList:
                return .none

            case .path(.element(id: _, action: .delegate(.serverUpdated(let server)))):
                if let index = state.serverList.servers.index(id: server.id) {
                    state.serverList.servers[index] = server
                }
                return .none

            case .path(.element(id: let id, action: .delegate(.serverDeleted(let serverID)))):
                state.path[id: id] = nil
                state.serverList.servers.remove(id: serverID)
                return .none

            case .path(.element(id: _, action: .delegate(.torrentSelected))):
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            ServerDetailReducer()
        }

        Scope(state: \.serverList, action: \.serverList) {
            ServerListReducer()
        }
    }
}
