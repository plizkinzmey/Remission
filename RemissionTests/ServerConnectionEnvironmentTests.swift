import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("ServerConnectionEnvironment")
struct ServerConnectionEnvironmentTests {
    @Test("isValid возвращает true при совпадении fingerprint")
    func isValidReturnsTrueForMatchingFingerprint() {
        // Этот тест фиксирует базовую проверку валидности окружения для сервера.
        let server = ServerConfig.previewLocalHTTP
        let environment = ServerConnectionEnvironment.testEnvironment(server: server)

        #expect(environment.isValid(for: server) == true)
    }

    @Test("isValid возвращает false при несовпадении fingerprint")
    func isValidReturnsFalseForDifferentFingerprint() {
        // Если fingerprint расходится, окружение нельзя переиспользовать.
        let server = ServerConfig.previewLocalHTTP
        var environment = ServerConnectionEnvironment.testEnvironment(server: server)
        environment.fingerprint = "different-fingerprint"

        #expect(environment.isValid(for: server) == false)
    }

    @Test("withDependencies применяет overrides и даёт доступ к transmissionClient")
    func withDependenciesAppliesOverrides() async throws {
        // Этот тест подтверждает, что withDependencies действительно подменяет
        // зависимости для асинхронной операции.
        let server = ServerConfig.previewLocalHTTP
        var client = TransmissionClientDependency.placeholder
        client.sessionGet = {
            TransmissionResponse(result: "success")
        }

        let environment = ServerConnectionEnvironment.testEnvironment(
            server: server,
            transmissionClient: client,
            torrentRepository: .testValue,
            sessionRepository: .placeholder
        )

        let result = try await environment.withDependencies {
            @Dependency(\.transmissionClient) var injectedClient
            let response = try await injectedClient.sessionGet()
            return response.result
        }

        #expect(result == "success")
    }

    @Test("updatingRPCVersion обновляет cacheKey и вызывает makeSnapshotClient")
    func updatingRPCVersionUpdatesCacheKey() async {
        // Важно обновлять cacheKey при смене RPC версии, чтобы кеш не конфликтовал.
        let server = ServerConfig.previewLocalHTTP
        let recorder = SnapshotClientRecorder()
        let cacheKey = OfflineCacheKey.make(
            server: server,
            credentialsFingerprint: "anonymous",
            rpcVersion: nil
        )
        let snapshot = OfflineCacheClient(
            load: { nil },
            updateTorrents: { torrents in
                ServerSnapshot(
                    torrents: CachedSnapshot(value: torrents, updatedAt: Date()),
                    session: nil
                )
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {}
        )

        let environment = ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: .placeholder,
                torrentRepository: .testValue,
                sessionRepository: .placeholder
            ),
            cacheKey: cacheKey,
            snapshot: snapshot,
            makeSnapshotClient: { key in
                recorder.record(key)
                return snapshot
            },
            rebuildRepositoriesOnVersionUpdate: false
        )

        let updated = environment.updatingRPCVersion(22)

        #expect(updated.cacheKey.rpcVersion == 22)
        #expect(recorder.receivedKey?.rpcVersion == 22)
    }
}

private final class SnapshotClientRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedKey: OfflineCacheKey?

    var receivedKey: OfflineCacheKey? {
        lock.lock()
        let value = storedKey
        lock.unlock()
        return value
    }

    func record(_ key: OfflineCacheKey) {
        lock.lock()
        storedKey = key
        lock.unlock()
    }
}
