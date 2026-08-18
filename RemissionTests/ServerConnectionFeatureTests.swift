import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Unified Server Connection Tests")
@MainActor
struct ServerConnectionFeatureTests {
    @Test("Task does not restart a terminal connection failure")
    func taskDoesNotRestartTerminalConnectionFailure() async {
        let server = ServerConfig.sample
        var state = ServerConnectionReducer.State(server: server)
        state.phase = .disconnected(.init(message: "Network unavailable", attempt: 3))
        state.failedConnectionAttempts = 3

        let store = TestStore(initialState: state) {
            ServerConnectionReducer()
        }

        await store.send(.task)
    }

    @Test("Automatic retry does not reconnect after success")
    func automaticRetryDoesNotReconnectAfterSuccess() async {
        let server = ServerConfig.sample
        let environment = ServerConnectionEnvironment.preview(server: server)
        let handshake = TransmissionHandshakeResult(
            sessionID: nil,
            rpcVersion: 20,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: nil,
            isCompatible: true
        )
        var state = ServerConnectionReducer.State(server: server)
        state.phase = .connected(.init(environment: environment, handshake: handshake))

        let store = TestStore(initialState: state) {
            ServerConnectionReducer()
        }

        await store.send(.retryRequested)
    }

    @Test("Retry immediately replaces disconnected state with connecting state")
    func retryStartsFromOneConsistentConnectionState() async {
        let server = ServerConfig.sample
        var state = ServerConnectionReducer.State(server: server)
        state.phase = .disconnected(.init(message: "Network unavailable", attempt: 1))

        let store = TestStore(initialState: state) {
            ServerConnectionReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionEnvironmentFactory = .unimplemented
        }
        store.exhaustivity = .off

        await store.send(.retryRequested) {
            $0.phase = .connecting
            $0.failedConnectionAttempts = 1
        }
    }

    @Test("Connection failure exposes one disconnected state")
    func connectionFailureDoesNotCreateParallelPresentationStates() async {
        let server = ServerConfig.sample
        var state = ServerConnectionReducer.State(server: server)
        state.phase = .connecting
        let error = ServerConnectionEnvironmentFactoryError.notConfigured("test")

        let store = TestStore(initialState: state) {
            ServerConnectionReducer()
        }
        store.exhaustivity = .off

        await store.send(.connectionResponse(.failure(error))) {
            $0.phase = .disconnected(.init(message: error.userFacingMessage, attempt: 1))
            $0.failedConnectionAttempts = 1
        }
    }

    @Test("Automatic retries retain the failure count and stop after the third failure")
    func automaticRetriesStopAfterThirdFailure() async {
        let server = ServerConfig.sample
        let error = ServerConnectionEnvironmentFactoryError.notConfigured("test")
        let clock = TestClock()
        var state = ServerConnectionReducer.State(server: server)
        state.phase = .disconnected(.init(message: error.userFacingMessage, attempt: 1))

        let store = TestStore(initialState: state) {
            ServerConnectionReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionEnvironmentFactory.make = { @Sendable _ in
                try await clock.sleep(for: .seconds(3_600))
                throw error
            }
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(.retryRequested) {
            $0.phase = .connecting
            $0.failedConnectionAttempts = 1
        }
        await store.send(.connectionResponse(.failure(error))) {
            $0.phase = .disconnected(.init(message: error.userFacingMessage, attempt: 2))
            $0.failedConnectionAttempts = 2
        }
        await store.send(.retryRequested) {
            $0.phase = .connecting
        }
        await store.send(.connectionResponse(.failure(error))) {
            $0.phase = .disconnected(.init(message: error.userFacingMessage, attempt: 3))
            $0.failedConnectionAttempts = 3
        }
        await store.send(.retryRequested)
        await store.skipInFlightEffects()
    }

    @Test("Manual retry resets terminal attempt count")
    func manualRetryResetsTerminalAttemptCount() async {
        let server = ServerConfig.sample
        let clock = TestClock()
        let error = ServerConnectionEnvironmentFactoryError.notConfigured("manual")
        var state = ServerConnectionReducer.State(server: server)
        state.phase = .disconnected(.init(message: "offline", attempt: 3))

        let store = TestStore(initialState: state) {
            ServerConnectionReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionEnvironmentFactory.make = { @Sendable _ in
                throw error
            }
            $0.appClock = .test(clock: clock)
        }

        await store.send(.manualRetryRequested) {
            $0.phase = .connecting
            $0.failedConnectionAttempts = 0
        }
        await store.receive(.connectionResponse(.failure(error))) {
            $0.phase = .disconnected(
                .init(
                    message: "ServerConnectionEnvironmentFactory (manual) не настроена.",
                    attempt: 1
                )
            )
            $0.failedConnectionAttempts = 1
        }
        await clock.advance(by: BackoffStrategy.delay(for: 1))
        await store.receive(.retryRequested) {
            $0.phase = .connecting
        }
        await store.receive(.connectionResponse(.failure(error))) {
            $0.phase = .disconnected(
                .init(
                    message: "ServerConnectionEnvironmentFactory (manual) не настроена.",
                    attempt: 2
                )
            )
            $0.failedConnectionAttempts = 2
        }
        await clock.advance(by: BackoffStrategy.delay(for: 2))
        await store.receive(.retryRequested) {
            $0.phase = .connecting
        }
        await store.receive(.connectionResponse(.failure(error))) {
            $0.phase = .disconnected(
                .init(
                    message: "ServerConnectionEnvironmentFactory (manual) не настроена.",
                    attempt: 3
                )
            )
            $0.failedConnectionAttempts = 3
        }
    }
}
