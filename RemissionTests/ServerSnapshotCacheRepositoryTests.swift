import Foundation
import Testing

@testable import Remission

@Suite("Server Snapshot Cache Repository")
struct ServerSnapshotCacheRepositoryTests {
    @Test("inMemory сохраняет переданную policy в репозитории")
    func inMemoryKeepsProvidedPolicy() {
        // Это простой, но полезный контракт: policy должна быть доступна вызывающему коду.
        let policy = OfflineCachePolicy(timeToLive: 5, maxBytesPerServer: 123)
        let repository = OfflineCacheRepository.inMemory(policy: policy)
        #expect(repository.policy == policy)
    }

    @Test("client.clear очищает только кеш конкретного serverID")
    func clientClearIsScopedToServerID() async throws {
        // Проверяем, что clear не затрагивает другие серверы.
        let repository = OfflineCacheRepository.inMemory()

        let id1 = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let id2 = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let key1 = OfflineCacheKey(serverID: id1, cacheFingerprint: "fp-1", rpcVersion: 17)
        let key2 = OfflineCacheKey(serverID: id2, cacheFingerprint: "fp-2", rpcVersion: 17)

        let client1 = repository.client(key1)
        let client2 = repository.client(key2)

        _ = try await client1.updateTorrents([.previewDownloading])
        _ = try await client2.updateTorrents([.previewCompleted])

        try await client1.clear()

        #expect(try await client1.load() == nil)
        #expect(try await client2.load()?.torrents?.value.count == 1)
    }
}
