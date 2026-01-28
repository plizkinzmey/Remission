import Foundation
import Testing

@testable import Remission

@Suite("TorrentRepository Cache Helpers")
struct TorrentRepositoryCacheTests {
    @Test("makeCacheListClosure ничего не делает, когда snapshot отсутствует")
    func cacheListNoopWhenSnapshotIsNil() async throws {
        // Этот тест фиксирует контракт: отсутствие snapshot не должно приводить к ошибкам.
        let closure = TorrentRepository.makeCacheListClosure(snapshot: nil)
        try await closure([.previewDownloading, .previewCompleted])
    }

    @Test("makeCacheListClosure прокидывает торренты в updateTorrents при успешном кеше")
    func cacheListUpdatesSnapshotOnSuccess() async throws {
        // Проверяем happy-path: торренты доходят до offline-cache клиента без искажений.
        let box = CacheCallBox()
        let snapshot = OfflineCacheClient(
            load: { nil },
            updateTorrents: { torrents in
                await box.recordUpdate(torrents)
                return ServerSnapshot(
                    torrents: CachedSnapshot(
                        value: torrents, updatedAt: Date(timeIntervalSince1970: 0)),
                    session: nil
                )
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {
                await box.recordClear()
            }
        )

        let torrents: [Torrent] = [.previewDownloading, .previewCompleted]
        let closure = TorrentRepository.makeCacheListClosure(snapshot: snapshot)
        try await closure(torrents)

        let recorded = await box.updatedTorrents
        #expect(recorded?.map(\.id) == torrents.map(\.id))
        #expect(await box.clearCount == 0)
    }

    @Test("makeCacheListClosure очищает кеш при exceedsSizeLimit")
    func cacheListClearsSnapshotOnSizeLimitError() async throws {
        // Это критичный сценарий: переполнение кеша не должно ломать флоу,
        // вместо этого кеш должен быть очищен.
        let box = CacheCallBox()
        let snapshot = OfflineCacheClient(
            load: { nil },
            updateTorrents: { torrents in
                await box.recordUpdate(torrents)
                throw OfflineCacheError.exceedsSizeLimit(bytes: 10_000_000, limit: 1)
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {
                await box.recordClear()
            }
        )

        let closure = TorrentRepository.makeCacheListClosure(snapshot: snapshot)
        try await closure([.previewDownloading])

        #expect(await box.clearCount == 1)
    }

    @Test("makeCacheListClosure пробрасывает ошибки, отличные от exceedsSizeLimit")
    func cacheListPropagatesUnexpectedErrors() async {
        // Мы явно фиксируем, что только exceedsSizeLimit обрабатывается локально,
        // остальные ошибки должны уходить выше по стеку.
        enum TestError: Error { case boom }

        let snapshot = OfflineCacheClient(
            load: { nil },
            updateTorrents: { _ in
                throw TestError.boom
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {}
        )

        let closure = TorrentRepository.makeCacheListClosure(snapshot: snapshot)

        do {
            try await closure([.previewDownloading])
            Issue.record("Ожидали ошибку TestError.boom, но она не была брошена")
        } catch is TestError {
            // OK
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }

    @Test("makeLoadCachedListClosure возвращает nil при отсутствии snapshot")
    func loadCachedListReturnsNilWhenSnapshotIsNil() async throws {
        // Контракт для вызывающего кода: отсутствие кеша = nil без ошибок.
        let closure = TorrentRepository.makeLoadCachedListClosure(snapshot: nil)
        let cached = try await closure()
        #expect(cached == nil)
    }

    @Test("makeLoadCachedListClosure возвращает torrents из snapshot.load")
    func loadCachedListReturnsCachedTorrents() async throws {
        // Проверяем, что мы действительно достаём именно torrents, а не весь snapshot целиком.
        let torrents: [Torrent] = [.previewDownloading]
        let expectedSnapshot = CachedSnapshot(
            value: torrents, updatedAt: Date(timeIntervalSince1970: 123))

        let snapshot = OfflineCacheClient(
            load: {
                ServerSnapshot(torrents: expectedSnapshot, session: nil)
            },
            updateTorrents: { torrents in
                ServerSnapshot(
                    torrents: CachedSnapshot(value: torrents, updatedAt: Date()), session: nil)
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {}
        )

        let closure = TorrentRepository.makeLoadCachedListClosure(snapshot: snapshot)
        let cached = try await closure()

        #expect(cached == expectedSnapshot)
    }

    @Test("makeLoadCachedListClosure возвращает nil, когда в snapshot нет torrents")
    func loadCachedListReturnsNilWhenTorrentsMissing() async throws {
        // Даже если snapshot существует, torrents могут отсутствовать — это валидный сценарий.
        let snapshot = OfflineCacheClient(
            load: {
                ServerSnapshot(torrents: nil, session: nil)
            },
            updateTorrents: { torrents in
                ServerSnapshot(
                    torrents: CachedSnapshot(value: torrents, updatedAt: Date()), session: nil)
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {}
        )

        let closure = TorrentRepository.makeLoadCachedListClosure(snapshot: snapshot)
        let cached = try await closure()

        #expect(cached == nil)
    }

    @Test("makeLoadCachedListClosure пробрасывает ошибки из snapshot.load")
    func loadCachedListPropagatesLoadErrors() async {
        // Ошибки загрузки кеша должны корректно доходить до вызывающего кода.
        enum TestError: Error { case failed }

        let snapshot = OfflineCacheClient(
            load: { throw TestError.failed },
            updateTorrents: { torrents in
                ServerSnapshot(
                    torrents: CachedSnapshot(value: torrents, updatedAt: Date()), session: nil)
            },
            updateSession: { session in
                ServerSnapshot(session: CachedSnapshot(value: session, updatedAt: Date()))
            },
            clear: {}
        )

        let closure = TorrentRepository.makeLoadCachedListClosure(snapshot: snapshot)

        do {
            _ = try await closure()
            Issue.record("Ожидали ошибку TestError.failed, но она не была брошена")
        } catch is TestError {
            // OK
        } catch {
            Issue.record("Получили неожиданный тип ошибки: \(error)")
        }
    }
}

private actor CacheCallBox {
    private(set) var updatedTorrents: [Torrent]?
    private(set) var clearCount: Int = 0

    func recordUpdate(_ torrents: [Torrent]) {
        updatedTorrents = torrents
    }

    func recordClear() {
        clearCount += 1
    }
}
