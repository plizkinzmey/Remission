import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct ServerListFeatureTests {
    @Test
    func addButtonShowsAlert() async {
        let store: TestStoreOf<ServerListReducer> = TestStore(initialState: .init()) {
            ServerListReducer()
        }

        await store.send(.addButtonTapped) {
            $0.alert = AlertState {
                TextState("Добавление сервера пока в разработке")
            } actions: {
                ButtonState(role: .cancel) {
                    TextState("Понятно")
                }
            }
        }

        await store.send(.alert(.dismiss)) {
            $0.alert = nil
        }
    }

    @Test
    func selectingServerTriggersDelegate() async {
        let server = ServerListReducer.State.Server(
            id: UUID(),
            name: "Seedbox",
            address: "https://seedbox.example.com"
        )
        let store: TestStoreOf<ServerListReducer> = TestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }()
        ) {
            ServerListReducer()
        }

        await store.send(.serverTapped(server.id))
        await store.receive(.delegate(.serverSelected(server)))
    }
}
