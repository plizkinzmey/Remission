import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    /// Запускает процесс подключения к серверу, учитывая флаг принудительного запуска.
    func startConnection(
        state: inout State,
        force: Bool
    ) -> Effect<Action> {
        guard case .connecting = state.connectionState.phase,
            force == false
        else {
            let shouldResetList =
                state.torrentList.items.isEmpty == false
                || state.torrentList.phase != .idle
            state.connectionEnvironment = nil
            state.lastAppliedDefaultSpeedLimits = nil
            state.connectionState.phase = .connecting
            state.connectionRetryAttempts = 0
            if shouldResetList {
                state.torrentList.items.removeAll()
                state.torrentList.storageSummary = nil
            }
            if state.torrentList.items.isEmpty {
                state.torrentList.phase = .loading
            }
            let resetEffect: Effect<Action> =
                shouldResetList
                ? .send(.torrentList(.resetForReconnect))
                : .none
            return .merge(
                .cancel(id: ConnectionCancellationID.connectionRetry),
                resetEffect,
                connect(server: state.server)
            )
        }

        return .none
    }

    /// Создаёт `ServerConnectionEnvironment` и выполняет handshake Transmission.
    func connect(server: ServerConfig) -> Effect<Action> {
        .run { send in
            await send(
                .connectionResponse(
                    TaskResult {
                        let environment = try await serverConnectionEnvironmentFactory.make(server)
                        await send(.cacheKeyPrepared(environment.cacheKey))
                        let handshake = try await environment.withDependencies {
                            @Dependency(\.transmissionClient) var client:
                                TransmissionClientDependency
                            return try await client.performHandshake()
                        }
                        return ConnectionResponse(environment: environment, handshake: handshake)
                    }
                )
            )
        }
        .cancellable(id: ConnectionCancellationID.connection, cancelInFlight: true)
    }

    func deleteServer(_ server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                if let key = server.credentialsKey {
                    try await credentialsRepository.delete(key: key)
                }
                try await offlineCacheRepository.clear(server.id)
                httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                _ = try await serverConfigRepository.delete([server.id])
                await send(.deleteCompleted(.success))
            } catch {
                await send(
                    .deleteCompleted(.failure(DeletionError(message: error.userFacingMessage))))
            }
        }
    }

    func performTrustReset(for server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                await send(.resetTrustSucceeded)
            } catch {
                await send(.resetTrustFailed(error.userFacingMessage))
            }
        }
    }

    func scheduleConnectionRetry(
        state: inout State
    ) -> Effect<Action> {
        guard state.connectionRetryAttempts < maxConnectionRetryAttempts else {
            return .none
        }
        let delay = BackoffStrategy.delay(for: state.connectionRetryAttempts)
        return .run { send in
            let clock = appClock.clock()
            do {
                try await clock.sleep(for: delay)
                await send(.retryConnectionButtonTapped)
            } catch is CancellationError {
                return
            }
        }
        .cancellable(id: ConnectionCancellationID.connectionRetry, cancelInFlight: true)
    }
}
