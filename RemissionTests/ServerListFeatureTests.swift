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
        } withDependencies: {
            $0.transmissionClient = .testValue
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
        var server = ServerConfig.previewSecureSeedbox
        let identifier = UUID()
        server.id = identifier
        let store: TestStoreOf<ServerListReducer> = TestStore(
            initialState: {
                var state: ServerListReducer.State = .init()
                state.servers = [server]
                return state
            }()
        ) {
            ServerListReducer()
        } withDependencies: {
            $0.transmissionClient = .testValue
        }

        await store.send(.serverTapped(identifier))
        await store.receive(.delegate(.serverSelected(server)))
    }
}
