import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    func deleteServer(_ server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                if let key = server.credentialsKey {
                    try await credentialsRepository.delete(key: key)
                }
                try await offlineCacheRepository.clear(server.id)
                await httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
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

}
