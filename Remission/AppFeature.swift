import ComposableArchitecture
import Foundation

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var serverList: ServerListReducer.State = .init()
        var path: StackState<ServerDetailReducer.State> = .init()
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

            case .serverList:
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
