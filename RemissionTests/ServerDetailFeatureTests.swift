import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

@MainActor
final class ServerDetailFeatureTests: XCTestCase {
    func testTask_StartsConnection() async {
        let server = ServerConfig.sample
        let gate = PreferencesGate()
        let handshake = TransmissionHandshakeResult(
            sessionID: "preview-session",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission Preview",
            isCompatible: true
        )
        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            handshake: handshake
        )

        let clock = TestClock()

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        } withDependencies: {
            // Этот сценарий проверяет подключение, а не подтверждение HTTP.
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionEnvironmentFactory = ServerConnectionEnvironmentFactory(make: {
                @Sendable _ in environment
            })
            $0.userPreferencesRepository.loadClosure = { @Sendable _ in
                await gate.wait()
                return .default
            }
            $0.userPreferencesRepository.observeClosure = { @Sendable _ in
                AsyncStream { $0.finish() }
            }
            $0.appClock = .test(clock: clock)
        }

        store.exhaustivity = .off

        await store.send(ServerDetailReducer.Action.task)

        // First effect: startConnection -> startConnectionAfterCheck
        await clock.advance(by: .seconds(1))

        await store.receive(ServerDetailReducer.Action.startConnectionAfterCheck(server, false))

        // Second effect: connect -> cacheKeyPrepared -> connectionResponse
        await clock.advance(by: .seconds(1))

        await store.receive(ServerDetailReducer.Action.cacheKeyPrepared(environment.cacheKey)) {
            $0.torrentList.cacheKey = environment.cacheKey
        }

        await store.receive(
            ServerDetailReducer.Action.connectionResponse(
                .success(
                    ServerDetailReducer.ConnectionResponse(
                        environment: environment,
                        handshake: handshake
                    )))
        ) { state in
            let updatedEnv = environment.updatingRPCVersion(handshake.rpcVersion)
            state.connectionState.phase = .ready(
                .init(fingerprint: updatedEnv.fingerprint, handshake: handshake))
            state.connectionEnvironment = updatedEnv

            state.torrentList.connectionEnvironment = updatedEnv
            state.torrentList.cacheKey = updatedEnv.cacheKey
            state.torrentList.handshake = handshake
        }

        await gate.open()

        await store.receive(ServerDetailReducer.Action.userPreferencesResponse(.success(.default)))
        {
            $0.preferences = .default
        }
    }
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
