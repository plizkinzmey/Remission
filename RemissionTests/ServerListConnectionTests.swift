import ComposableArchitecture
import Foundation
import XCTest

@testable import Remission

@MainActor
final class ServerListConnectionTests: XCTestCase {
    func testConnectionProbeSuccess() async {
        // Проверяем, что успешный probe переводит сервер в connected и запускает загрузку storage.
        let server = ServerConfig.previewLocalHTTP
        let handshake = TransmissionHandshakeResult(
            sessionID: "probe",
            rpcVersion: 17,
            minimumSupportedRpcVersion: 14,
            serverVersionDescription: "Transmission",
            isCompatible: true
        )
        let result = ServerConnectionProbe.Result(handshake: handshake)

        let clock = TestClock()

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionProbe.run = { @Sendable _, _ in result }
            $0.credentialsRepository.load = { @Sendable _ in
                TransmissionServerCredentials(
                    key: server.credentialsKey!,
                    password: "secret"
                )
            }
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(.connectionProbeRequested(server.id))

        await clock.advance(by: .seconds(1))

        await store.receive(.startConnectionProbe(server)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.connectionProbeResponse(server.id, .success(result))) {
            $0.connectionStatuses[server.id] = .init(phase: .connected(handshake))
        }

        await store.receive(.storageRequested(server.id))
    }
    func testConnectionProbeFailure() async {
        // Проверяем, что ошибка probe переводит статус в failed.
        let server = ServerConfig.previewLocalHTTP
        let error = TestError(message: "fail")

        let clock = TestClock()

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.serverConnectionProbe.run = { @Sendable _, _ in throw error }
            $0.credentialsRepository.load = { @Sendable _ in
                TransmissionServerCredentials(
                    key: server.credentialsKey!,
                    password: "secret"
                )
            }
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(.connectionProbeRequested(server.id))

        await clock.advance(by: .seconds(1))

        await store.receive(.startConnectionProbe(server)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await clock.advance(by: .seconds(1))

        await store.receive(.connectionProbeResponse(server.id, .failure(error))) {
            $0.connectionStatuses[server.id] = .init(phase: .failed(error.message))
        }
    }
    func testConnectionProbeMissingCredentials() async {
        // Проверяем, что при отсутствии credentials probe возвращает ошибку и статус failed.
        let server = ServerConfig.previewLocalHTTP

        let clock = TestClock()

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.httpWarningPreferencesStore.isSuppressed = { @Sendable _ in true }
            $0.credentialsRepository.load = { @Sendable _ in nil }
            $0.appClock = .test(clock: clock)
        }
        store.exhaustivity = .off

        await store.send(.connectionProbeRequested(server.id))

        await clock.advance(by: .seconds(1))

        await store.receive(.startConnectionProbe(server)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await clock.advance(by: .seconds(1))

        await store.receive(
            ServerListReducer.Action.connectionProbeResponse(
                server.id,
                .failure(
                    ServerConnectionEnvironmentFactoryError.missingCredentials
                ))
        ) {
            $0.connectionStatuses[server.id] = .init(
                phase: .failed(
                    ServerConnectionEnvironmentFactoryError.missingCredentials
                        .errorDescription ?? ""
                )
            )
        }
    }
}

private struct TestError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
