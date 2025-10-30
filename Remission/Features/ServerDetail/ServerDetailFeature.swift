import ComposableArchitecture
import Foundation

@Reducer
struct ServerDetailReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerListReducer.Server
    }

    enum Action: Equatable {
        case task
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .task:
                return .none
            }
        }
    }
}
