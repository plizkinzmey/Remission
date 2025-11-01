import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AppFeatureTests {
    @Test
    func selectingServerPushesDetail() async {
        var server = ServerConfig.previewLocalHTTP
        let identifier = UUID()
        server.id = identifier
        let store: TestStoreOf<AppReducer> = TestStore(
            initialState: {
                var state: AppReducer.State = .init()
                state.serverList.servers = [server]
                return state
            }()
        ) {
            AppReducer()
        } withDependencies: {
            $0.transmissionClient = .testValue
        }
        store.exhaustivity = .off

        await store.send(.serverList(.serverTapped(identifier)))
        await store.receive(.serverList(.delegate(.serverSelected(server))))

        #expect(store.state.path.last?.server == server)
        #expect(store.state.path.count == 1)
    }
}
