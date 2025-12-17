import Foundation
import Testing

@testable import Remission

@Suite("Offline cache policy")
struct OfflineCacheRepositoryTests {
    @Test("Просроченный кеш очищается и не возвращается")
    func cacheExpiresAfterTTL() async throws {
        let current = DateBox(Date(timeIntervalSince1970: 1_000))
        let policy = OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 1024 * 1024)
        let cache = OfflineCacheRepository.inMemory(policy: policy, now: { current.value })
        let key = OfflineCacheKey(
            serverID: UUID(),
            cacheFingerprint: "ttl-fixture",
            rpcVersion: 20
        )
        let client = cache.client(key)

        _ = try await client.updateTorrents([Torrent.previewDownloading])
        #expect(try await client.load() != nil)

        current.value = current.value.addingTimeInterval(120)
        let expired = try await client.load()

        #expect(expired == nil)
    }

    @Test("Кеш инвалидируется при несовпадении RPC версии")
    func cacheInvalidatedByRpcVersionMismatch() async throws {
        let cache = OfflineCacheRepository.inMemory()
        let serverID = UUID()
        let baseFingerprint = "version-fixture"
        let originalKey = OfflineCacheKey(
            serverID: serverID,
            cacheFingerprint: baseFingerprint,
            rpcVersion: 20
        )
        let client = cache.client(originalKey)
        _ = try await client.updateTorrents([.previewDownloading])

        let mismatchedKey = OfflineCacheKey(
            serverID: serverID,
            cacheFingerprint: baseFingerprint,
            rpcVersion: 21
        )
        let mismatchedClient = cache.client(mismatchedKey)
        let loaded = try await mismatchedClient.load()

        #expect(loaded == nil)
        let originalAfterMismatch = try await client.load()
        #expect(originalAfterMismatch == nil)
    }

    @Test("Превышение лимита размера очищает кеш и возвращает ошибку")
    func cacheEvictedOnSizeLimit() async throws {
        let tinyPolicy = OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 1)
        let cache = OfflineCacheRepository.inMemory(policy: tinyPolicy)
        let key = OfflineCacheKey(
            serverID: UUID(),
            cacheFingerprint: "size-fixture",
            rpcVersion: 20
        )
        let client = cache.client(key)

        do {
            _ = try await client.updateTorrents([.previewDownloading])
            Issue.record("Expected size limit error")
        } catch let error as OfflineCacheError {
            switch error {
            case .exceedsSizeLimit:
                break
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        let afterEviction = try? await client.load()
        #expect(afterEviction == nil)
    }
}

private final class DateBox: @unchecked Sendable {
    var value: Date

    init(_ value: Date) {
        self.value = value
    }
}
