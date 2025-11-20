import ComposableArchitecture
import Foundation

@Reducer
struct AddTorrentReducer {
    @ObservableState
    struct State: Equatable {
        var pendingInput: PendingTorrentInput
        var connectionEnvironment: ServerConnectionEnvironment?
    }

    enum Action: Equatable {
        case closeButtonTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case closeRequested
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .closeButtonTapped:
                return .send(.delegate(.closeRequested))
            case .delegate:
                return .none
            }
        }
    }
}
