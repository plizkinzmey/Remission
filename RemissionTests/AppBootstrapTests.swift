import Foundation
import Testing

@testable import Remission

@MainActor
struct AppBootstrapTests {
    @Test
    func defaultArgumentsProduceEmptyServerList() {
        let state = AppBootstrap.makeInitialState(arguments: [])
        #expect(state.serverList.servers.isEmpty)
        #expect(state.path.isEmpty)
    }

    @Test
    func uiFixturePopulatesSampleServers() {
        let arguments = ["--ui-testing-fixture=server-list-sample"]
        let state = AppBootstrap.makeInitialState(arguments: arguments)
        #expect(state.serverList.servers.count == 2)
        #expect(state.serverList.servers.first?.name == "UI Test NAS")
        #expect(state.serverList.servers.last?.name == "UI Test Seedbox")
    }
}
