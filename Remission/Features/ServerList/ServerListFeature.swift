import ComposableArchitecture
import Foundation

@Reducer
struct ServerListReducer {
    struct Server: Equatable, Identifiable, Sendable {
        var id: UUID
        var name: String
        var address: String
    }

    @ObservableState
    struct State: Equatable {
        var servers: IdentifiedArrayOf<Server> = []
        var isLoading: Bool = false
        @Presents var alert: AlertState<Alert>?
    }

    enum Action: Equatable {
        case task
        case addButtonTapped
        case serverTapped(UUID)
        case remove(IndexSet)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
    }

    enum Alert: Equatable {
        case comingSoon
    }

    enum Delegate: Equatable {
        case serverSelected(Server)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                if state.servers.isEmpty {
                    state.isLoading = false
                }
                return .none

            case .addButtonTapped:
                state.alert = AlertState {
                    TextState("Добавление сервера пока в разработке")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("Понятно")
                    }
                }
                return .none

            case .serverTapped(let id):
                guard let server = state.servers[id: id] else {
                    return .none
                }
                return .send(.delegate(.serverSelected(server)))

            case .remove(let indexSet):
                state.servers.remove(atOffsets: indexSet)
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }
}
