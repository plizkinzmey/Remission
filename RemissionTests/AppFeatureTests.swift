import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AppFeatureTests {
    @Test
    func selectingServerPushesDetail() async {
        let server = ServerListReducer.State.Server(
            id: UUID(),
            name: "NAS",
            address: "http://nas.local:9091"
        )
        let store: TestStoreOf<AppReducer> = TestStore(
            initialState: {
                var state: AppReducer.State = .init()
                state.serverList.servers = [server]
                return state
            }()
        ) {
            AppReducer()
        }
        store.exhaustivity = .off

        await store.send(.serverList(.serverTapped(server.id)))
        await store.receive(.serverList(.delegate(.serverSelected(server))))

        #expect(store.state.path.last?.server == server)
        #expect(store.state.path.count == 1)
    }
}
