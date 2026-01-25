import Foundation
import Testing

@testable import Remission

@Suite("OfflineCacheFileStore")
struct OfflineCacheFileStoreTests {
    @Test("update -> load возвращает сохранённый snapshot")
    func updateThenLoadReturnsSnapshot() async throws {
        // Базовый контракт кеша: после update мы должны прочитать те же данные через load.
        let fixture = makeStore(policy: .init(timeToLive: 60, maxBytesPerServer: 1_000_000))
        defer { fixture.cleanup() }

        fixture.nowBox.now = Date(timeIntervalSince1970: 10)
        let torrents = [Torrent.sampleDownloading(), Torrent.sampleSeeding()]

        _ = try await fixture.store.update(key: fixture.key, torrents: torrents)
        let loaded = try await fixture.store.load(key: fixture.key)

        #expect(loaded?.torrents?.value == torrents)
    }

    @Test("load возвращает nil, когда snapshot устарел по TTL")
    func loadReturnsNilWhenExpired() async throws {
        // Кеш должен защищать UI от слишком старых данных.
        let fixture = makeStore(policy: .init(timeToLive: 5, maxBytesPerServer: 1_000_000))
        defer { fixture.cleanup() }

        fixture.nowBox.now = Date(timeIntervalSince1970: 0)
        _ = try await fixture.store.update(
            key: fixture.key,
            torrents: [Torrent.sampleDownloading()]
        )

        // Сдвигаем «текущее время» за предел TTL.
        fixture.nowBox.now = Date(timeIntervalSince1970: 6)
        let loaded = try await fixture.store.load(key: fixture.key)

        #expect(loaded == nil)
    }

    @Test("Несовпадение fingerprint инвалидирует кеш без падения")
    func fingerprintMismatchInvalidatesCache() async throws {
        // Это ключевой сценарий безопасности: кеш не должен переживать смену учётных данных/endpoint.
        let fixture = makeStore(policy: .init(timeToLive: 60, maxBytesPerServer: 1_000_000))
        defer { fixture.cleanup() }

        _ = try await fixture.store.update(
            key: fixture.key, torrents: [Torrent.sampleDownloading()])

        var mismatchedKey = fixture.key
        mismatchedKey.cacheFingerprint = "different-fingerprint"

        let loaded = try await fixture.store.load(key: mismatchedKey)
        #expect(loaded == nil)
    }

    @Test("Превышение лимита размера бросает ошибку и очищает кеш")
    func sizeLimitExceededThrowsAndClearsCache() async throws {
        // Мы намеренно ставим очень маленький лимит, чтобы гарантировать ошибку сериализации.
        let smallPolicy = OfflineCachePolicy(timeToLive: 60, maxBytesPerServer: 1)
        let fixture = makeStore(policy: smallPolicy)
        defer { fixture.cleanup() }

        do {
            _ = try await fixture.store.update(
                key: fixture.key, torrents: [Torrent.sampleDownloading()])
            Issue.record("Ожидали OfflineCacheError.exceedsSizeLimit, но ошибка не была брошена")
        } catch let error as OfflineCacheError {
            switch error {
            case .exceedsSizeLimit:
                break
            default:
                Issue.record("Получили неверный тип OfflineCacheError: \(error)")
            }
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }

        let loaded = try await fixture.store.load(key: fixture.key)
        #expect(loaded == nil)
    }
}

private func makeStore(policy: OfflineCachePolicy) -> OfflineCacheFileStoreFixture {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "OfflineCacheFileStoreTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    let nowBox = NowBox(now: Date(timeIntervalSince1970: 0))
    let store = OfflineCacheFileStore(
        baseDirectory: tempDirectory,
        policy: policy,
        now: { nowBox.now },
        log: .noop
    )
    let key = OfflineCacheKey(serverID: UUID(), cacheFingerprint: "fingerprint", rpcVersion: 17)

    let cleanup: () -> Void = {
        _ = try? FileManager.default.removeItem(at: tempDirectory)
    }

    return OfflineCacheFileStoreFixture(store: store, key: key, nowBox: nowBox, cleanup: cleanup)
}

private final class NowBox: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private struct OfflineCacheFileStoreFixture {
    var store: OfflineCacheFileStore
    var key: OfflineCacheKey
    var nowBox: NowBox
    var cleanup: () -> Void
}
