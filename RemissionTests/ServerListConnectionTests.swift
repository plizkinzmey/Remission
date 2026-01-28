import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Server List Connection Tests")
@MainActor
struct ServerListConnectionTests {

    @Test("Успешный probe обновляет статус и запрашивает storage")
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

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConnectionProbe.run = { @Sendable _, _ in result }
            $0.credentialsRepository.load = { @Sendable _ in
                TransmissionServerCredentials(
                    key: server.credentialsKey!,
                    password: "secret"
                )
            }
        }
        store.exhaustivity = .off

        await store.send(.connectionProbeRequested(server.id)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await store.receive(.connectionProbeResponse(server.id, .success(result))) {
            $0.connectionStatuses[server.id] = .init(phase: .connected(handshake))
        }

        await store.receive(.storageRequested(server.id))
    }

    @Test("Ошибка probe записывает статус failed")
    func testConnectionProbeFailure() async {
        // Проверяем, что ошибка probe переводит статус в failed.
        let server = ServerConfig.previewLocalHTTP
        let error = TestError(message: "fail")

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.serverConnectionProbe.run = { @Sendable _, _ in throw error }
            $0.credentialsRepository.load = { @Sendable _ in
                TransmissionServerCredentials(
                    key: server.credentialsKey!,
                    password: "secret"
                )
            }
        }
        store.exhaustivity = .off

        await store.send(.connectionProbeRequested(server.id)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

        await store.receive(.connectionProbeResponse(server.id, .failure(error))) {
            $0.connectionStatuses[server.id] = .init(phase: .failed(error.message))
        }
    }

    @Test("Отсутствующие credentials переводят probe в failed")
    func testConnectionProbeMissingCredentials() async {
        // Проверяем, что при отсутствии credentials probe возвращает ошибку и статус failed.
        let server = ServerConfig.previewLocalHTTP

        var state = ServerListReducer.State()
        state.servers = [server]

        let store = TestStore(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0.credentialsRepository.load = { @Sendable _ in nil }
        }
        store.exhaustivity = .off

        await store.send(.connectionProbeRequested(server.id)) {
            $0.connectionStatuses[server.id] = .init(phase: .probing)
        }

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
