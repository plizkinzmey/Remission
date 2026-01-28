import Foundation
import Testing

@testable import Remission

@Suite("In-Memory Offline Cache Store Tests")
struct InMemoryOfflineCacheStoreTests {
    private final class TimeBox: @unchecked Sendable {
        var now: Date
        init(now: Date) { self.now = now }
    }

    private func makeKey(fingerprint: String = "fp") -> OfflineCacheKey {
        OfflineCacheKey(
            serverID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            cacheFingerprint: fingerprint,
            rpcVersion: 17
        )
    }

    // Проверяет базовый сценарий update -> load при свежем кеше.
    @Test
    func updateThenLoadReturnsSnapshot() async throws {
        let time = TimeBox(now: Date(timeIntervalSince1970: 100))
        let store = InMemoryOfflineCacheStore(
            policy: OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 1_000_000),
            now: { time.now },
            log: .noop
        )

        _ = try await store.update(key: makeKey(), torrents: [Torrent.previewDownloading])
        let snapshot = await store.load(key: makeKey())

        #expect(snapshot?.torrents?.value.count == 1)
        #expect(snapshot?.session == nil)
    }

    // Проверяет инвалидирование кеша при несовпадении fingerprint.
    @Test
    func loadInvalidatesCacheOnFingerprintMismatch() async throws {
        let time = TimeBox(now: Date(timeIntervalSince1970: 100))
        let store = InMemoryOfflineCacheStore(
            policy: OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 1_000_000),
            now: { time.now },
            log: .noop
        )

        _ = try await store.update(
            key: makeKey(fingerprint: "fp1"),
            torrents: [Torrent.previewDownloading]
        )
        let snapshot = await store.load(key: makeKey(fingerprint: "fp2"))
        #expect(snapshot == nil)
    }

    // Проверяет протухание кеша по TTL.
    @Test
    func loadReturnsNilWhenCacheExpired() async throws {
        let time = TimeBox(now: Date(timeIntervalSince1970: 100))
        let store = InMemoryOfflineCacheStore(
            policy: OfflineCachePolicy(timeToLive: 10, maxBytesPerServer: 1_000_000),
            now: { time.now },
            log: .noop
        )

        _ = try await store.update(key: makeKey(), session: .previewActive)
        time.now = Date(timeIntervalSince1970: 200)

        let snapshot = await store.load(key: makeKey())
        #expect(snapshot == nil)
    }

    // Проверяет ошибку превышения лимита размера.
    @Test
    func updateThrowsWhenSizeLimitExceeded() async {
        let time = TimeBox(now: Date(timeIntervalSince1970: 100))
        let store = InMemoryOfflineCacheStore(
            policy: OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 10),
            now: { time.now },
            log: .noop
        )

        var didThrow = false
        do {
            _ = try await store.update(key: makeKey(), torrents: [Torrent.previewDownloading])
        } catch {
            didThrow = true
        }

        #expect(didThrow)
        let snapshot = await store.load(key: makeKey())
        #expect(snapshot == nil)
    }
}
