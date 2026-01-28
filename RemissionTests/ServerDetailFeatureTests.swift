import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server Detail Feature Tests")
@MainActor
struct ServerDetailFeatureTests {

    @Test("Task starts connection and loads preferences")
    func testTask_StartsConnection() async {
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)
        let gate = PreferencesGate()
        let handshake = TransmissionHandshakeResult(
            sessionID: "preview-session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission Preview",
            isCompatible: true
        )

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        } withDependencies: {
            $0.serverConnectionEnvironmentFactory.make = { @Sendable _ in environment }
            $0.userPreferencesRepository.loadClosure = { @Sendable _ in
                await gate.wait()
                return .default
            }
            $0.userPreferencesRepository.observeClosure = { @Sendable _ in
                AsyncStream { $0.finish() }
            }
            $0.transmissionClient.performHandshake = { @Sendable in handshake }
            $0.appClock.clock = { @Sendable in ContinuousClock() }
        }

        store.exhaustivity = .off

        await store.send(ServerDetailReducer.Action.task)

        await store.receive(ServerDetailReducer.Action.cacheKeyPrepared(environment.cacheKey)) {
            $0.torrentList.cacheKey = environment.cacheKey
        }

        await store.receive(\.connectionResponse.success) {
            let updatedEnv = environment.updatingRPCVersion(handshake.rpcVersion)
            $0.connectionState.phase = .ready(
                .init(fingerprint: updatedEnv.fingerprint, handshake: handshake))
            $0.connectionEnvironment = updatedEnv

            $0.torrentList.connectionEnvironment = updatedEnv
            $0.torrentList.cacheKey = updatedEnv.cacheKey
            $0.torrentList.handshake = handshake
        }

        await gate.open()

        await store.receive(\.userPreferencesResponse.success) {
            $0.preferences = .default
        }
    }

    @Test("Settings button tapped presents settings")
    func testSettingsButtonTapped() async {
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.previewValue

        var state = ServerDetailReducer.State(server: server)
        state.connectionEnvironment = environment

        let store = TestStore(initialState: state) {
            ServerDetailReducer()
        }

        await store.send(ServerDetailReducer.Action.settingsButtonTapped) {
            $0.settings = SettingsReducer.State(
                serverID: server.id,
                serverName: server.name,
                connectionEnvironment: environment,
                isLoading: true
            )
        }
    }
}

private actor PreferencesGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func open() {
        guard isOpen == false else { return }
        isOpen = true
        for continuation in continuations {
            continuation.resume()
        }
        continuations.removeAll()
    }
}
