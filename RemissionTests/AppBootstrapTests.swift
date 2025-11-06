import ComposableArchitecture
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
        #expect(state.version == .latest)
    }

    @Test
    func uiFixturePopulatesSampleServers() {
        let arguments = ["--ui-testing-fixture=server-list-sample"]
        let state = AppBootstrap.makeInitialState(arguments: arguments)
        #expect(state.serverList.servers.count == 2)
        #expect(state.serverList.servers.first?.name == "UI Test NAS")
        #expect(state.serverList.servers.last?.name == "UI Test Seedbox")
    }

    @Test
    func migratingLegacyStateClearsPathAndBumpsVersion() {
        var serverList = ServerListReducer.State()
        serverList.servers = [ServerConfig.previewLocalHTTP]
        let detailState = ServerDetailReducer.State(server: .previewLocalHTTP)
        let legacy = AppReducer.State(
            version: .legacy,
            serverList: serverList,
            path: StackState([detailState])
        )

        let migrated = AppBootstrap.makeInitialState(
            arguments: [],
            targetVersion: .latest,
            existingState: legacy
        )

        #expect(migrated.version == .latest)
        #expect(migrated.path.isEmpty)
        #expect(migrated.serverList.servers == legacy.serverList.servers)
    }
}
