import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

// swiftlint:disable function_body_length
@MainActor
struct ServerDetailConnectionBasicsTests {
    @Test
    func taskInitializesConnectionEnvironment() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "session-1",
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0.3",
            isCompatible: true
        )
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake
        )
        let preferences = DomainFixtures.userPreferences

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .mock(environment: environment)
            dependencies.userPreferencesRepository = .serverDetailTestValue(
                preferences: preferences
            )
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.connectionState.phase = .connecting
        }
        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.preferences = preferences
        }
        await store.send(
            .connectionResponse(.success(.init(environment: environment, handshake: handshake)))
        ) {
            $0.connectionEnvironment = environment
            $0.connectionState.phase = .ready(
                .init(fingerprint: environment.fingerprint, handshake: handshake)
            )
            $0.torrentList.connectionEnvironment = environment
            $0.lastAppliedDefaultSpeedLimits = preferences.defaultSpeedLimits
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }
    }

    @Test
    func torrentDetailReusesExistingConnectionEnvironment() async {
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "session-42",
            rpcVersion: 21,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.1",
            isCompatible: true
        )
        let torrent = DomainFixtures.torrentDownloading
        let repository = TorrentRepository.test(fetchList: { [torrent] })
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake,
            torrentRepository: repository
        )
        let preferences = DomainFixtures.userPreferences

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .mock(environment: environment)
            dependencies.userPreferencesRepository = .serverDetailTestValue(
                preferences: preferences
            )
            dependencies.torrentRepository = repository
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.connectionState.phase = .connecting
        }
        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.preferences = preferences
        }
        await store.send(
            .connectionResponse(.success(.init(environment: environment, handshake: handshake)))
        ) {
            $0.connectionEnvironment = environment
            $0.connectionState.phase = .ready(
                .init(fingerprint: environment.fingerprint, handshake: handshake)
            )
            $0.torrentList.connectionEnvironment = environment
            $0.lastAppliedDefaultSpeedLimits = preferences.defaultSpeedLimits
        }

        await store.send(.torrentList(.torrentsResponse(.success([torrent])))) {
            $0.torrentList.phase = .loaded
            $0.torrentList.items = [TorrentListItem.State(torrent: torrent)]
        }

        await store.send(.torrentList(.delegate(.openTorrent(torrent.id)))) {
            #expect($0.torrentDetail?.connectionEnvironment == environment)
            #expect($0.torrentDetail?.torrentID == torrent.id)
        }
    }

    @Test
    func addTorrentCompletionDelegatesToList() async {
        let server = ServerConfig.previewLocalHTTP
        let addResult = TorrentRepository.AddResult(
            status: .added,
            id: .init(rawValue: 321),
            name: "Queued Torrent",
            hashString: "hash-321"
        )
        let environment = ServerConnectionEnvironment.preview(server: server)
        var initialState = ServerDetailReducer.State(server: server)
        initialState.connectionEnvironment = environment
        initialState.torrentList.connectionEnvironment = environment
        initialState.addTorrent = AddTorrentReducer.State(
            pendingInput: PendingTorrentInput(
                payload: .magnetLink(
                    url: URL(string: "magnet:?xt=urn:btih:queued")!,
                    rawValue: "magnet:?xt=urn:btih:queued"
                ),
                sourceDescription: "Magnet"
            ),
            connectionEnvironment: environment
        )

        let store = TestStore(
            initialState: initialState
        ) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }
        store.exhaustivity = .off

        await store.send(.addTorrent(.presented(.delegate(.addCompleted(addResult)))))
        await store.receive(.torrentList(.delegate(.added(addResult))))
    }

    @Test
    func connectionFailureShowsAlert() async {
        let server = ServerConfig.previewSecureSeedbox
        let expectedError = ServerConnectionEnvironmentFactoryError.missingCredentials

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: server)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .init { _ in
                throw expectedError
            }
            dependencies.userPreferencesRepository = .serverDetailTestValue(
                preferences: DomainFixtures.userPreferences
            )
        }
        store.exhaustivity = .off

        await store.send(.task)

        await store.receive(.connectionResponse(.failure(expectedError)), timeout: .seconds(1)) {
            $0.connectionEnvironment = nil
            $0.connectionState.phase = .failed(.init(message: expectedError.errorDescription ?? ""))
            $0.alert = .connectionFailure(message: expectedError.errorDescription ?? "")
        }
    }

    @Test
    func serverUpdateReinitializesConnection() async {
        var initialServer = ServerConfig.previewLocalHTTP
        initialServer.name = "NAS"
        var updatedServer = initialServer
        updatedServer.connection = .init(host: "updated-nas.local", port: 9091)

        let firstHandshake = TransmissionHandshakeResult(
            sessionID: "first",
            rpcVersion: 19,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.0",
            isCompatible: true
        )
        let secondHandshake = TransmissionHandshakeResult(
            sessionID: "second",
            rpcVersion: 21,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission 4.1",
            isCompatible: true
        )

        let firstEnvironment = ServerConnectionEnvironment.testEnvironment(
            server: initialServer,
            handshake: firstHandshake
        )
        let secondEnvironment = ServerConnectionEnvironment.testEnvironment(
            server: updatedServer,
            handshake: secondHandshake
        )

        let invocationCount = ServerDetailLockedValue(0)
        let preferences = DomainFixtures.userPreferences

        let store = TestStore(
            initialState: ServerDetailReducer.State(server: initialServer)
        ) {
            ServerDetailReducer()
        } withDependencies: { dependencies in
            dependencies = AppDependencies.makeTestDefaults()
            dependencies.serverConnectionEnvironmentFactory = .init { _ in
                let index = min(invocationCount.value, 1)
                invocationCount.withValue { $0 += 1 }
                return index == 0 ? firstEnvironment : secondEnvironment
            }
            dependencies.userPreferencesRepository = .serverDetailTestValue(
                preferences: preferences
            )
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.connectionState.phase = .connecting
        }
        await store.send(.userPreferencesResponse(.success(preferences))) {
            $0.preferences = preferences
        }
        await store.send(
            .connectionResponse(
                .success(.init(environment: firstEnvironment, handshake: firstHandshake))
            )
        ) {
            $0.connectionEnvironment = firstEnvironment
            $0.connectionState.phase = .ready(
                .init(fingerprint: firstEnvironment.fingerprint, handshake: firstHandshake)
            )
            $0.torrentList.connectionEnvironment = firstEnvironment
            $0.lastAppliedDefaultSpeedLimits = preferences.defaultSpeedLimits
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }

        await store.send(.editButtonTapped) {
            $0.editor = ServerEditorReducer.State(server: initialServer)
        }

        await store.send(.editor(.presented(.delegate(.didUpdate(updatedServer))))) {
            $0.server = updatedServer
            $0.editor = nil
            $0.connectionEnvironment = nil
            $0.torrentList = TorrentListReducer.State()
        }

        await store.receive(.torrentList(.teardown))
        await store.receive(.delegate(.serverUpdated(updatedServer)))

        await store.send(
            .connectionResponse(
                .success(
                    ServerDetailReducer.ConnectionResponse(
                        environment: secondEnvironment,
                        handshake: secondHandshake
                    )
                )
            )
        ) {
            $0.connectionEnvironment = secondEnvironment
            $0.connectionState.phase = .ready(
                .init(fingerprint: secondEnvironment.fingerprint, handshake: secondHandshake)
            )
            $0.torrentList.connectionEnvironment = secondEnvironment
            $0.lastAppliedDefaultSpeedLimits = preferences.defaultSpeedLimits
        }
        await store.receive(.torrentList(.task)) {
            $0.torrentList.phase = .loading
        }
    }
}
// swiftlint:enable function_body_length
