import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
struct AppBootstrapTests {
    @Test
    func defaultArgumentsProduceEmptyServerList() {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-bootstrap-empty-\(UUID().uuidString)")
        let state = AppBootstrap.makeInitialState(arguments: [], storageFileURL: temp)
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

    @Test
    func loadsPersistedServersFromStorage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-bootstrap-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("servers.json", isDirectory: false)
        let server = ServerConfig.previewSecureSeedbox
        let record = StoredServerConfigRecord(
            id: server.id,
            name: server.name,
            host: server.connection.host,
            port: server.connection.port,
            path: server.connection.path == "/transmission/rpc" ? nil : server.connection.path,
            isSecure: server.isSecure,
            allowUntrustedCertificates: {
                if case .https(let allow) = server.security { return allow }
                return false
            }(),
            username: server.authentication?.username,
            createdAt: server.createdAt
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([record])
        try data.write(to: fileURL, options: .atomic)

        let state = AppBootstrap.makeInitialState(arguments: [], storageFileURL: fileURL)

        #expect(state.serverList.servers.count == 1)
        #expect(state.serverList.servers.first?.id == server.id)
        #expect(state.serverList.shouldLoadServersFromRepository == false)
    }
}
