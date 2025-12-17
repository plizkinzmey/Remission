import Foundation
import Testing

@testable import Remission

@Suite("DiagnosticsLogStore")
struct DiagnosticsLogStoreTests {
    @Test("буфер ограничивает количество записей и возвращает последние сначала")
    func respectsMaxEntries() async throws {
        let store = DiagnosticsLogStore.inMemory(maxEntries: 2)

        let first = DomainFixtures.diagnosticsEntry(message: "first", level: .info)
        let second = DomainFixtures.diagnosticsEntry(message: "second", level: .warning)
        let third = DomainFixtures.diagnosticsEntry(message: "third", level: .error)

        await store.append(first)
        await store.append(second)
        await store.append(third)

        let snapshot = try await store.load(.init())
        #expect(snapshot.count == 2)
        #expect(snapshot.first?.message == third.message)
        #expect(snapshot.last?.message == second.message)
    }

    @Test("фильтрация по уровню и поиску отбрасывает нерелевантные записи")
    func filtersByLevelAndSearch() async throws {
        let store = DiagnosticsLogStore.inMemory()
        let warning = DomainFixtures.diagnosticsEntry(
            message: "Retry request",
            level: .warning,
            category: "transmission",
            metadata: ["method": "torrent-get"]
        )
        let info = DomainFixtures.diagnosticsEntry(
            message: "Connected",
            level: .info,
            category: "bootstrap"
        )
        await store.append(warning)
        await store.append(info)

        let levelFilter = DiagnosticsLogFilter(level: .warning, searchText: "")
        let levelResult = try await store.load(levelFilter)
        #expect(levelResult.count == 1)
        #expect(levelResult.first?.level == .warning)

        let searchFilter = DiagnosticsLogFilter(level: nil, searchText: "bootstrap")
        let searchResult = try await store.load(searchFilter)
        #expect(searchResult.count == 1)
        #expect(searchResult.first?.category == "bootstrap")
    }

    @Test("observe поток возвращает обновления после добавления записей")
    func observeStreamEmitsUpdates() async throws {
        let store = DiagnosticsLogStore.inMemory()
        var iterator = await store.observe(.init()).makeAsyncIterator()

        _ = await iterator.next()  // initial yield

        let entry = DomainFixtures.diagnosticsEntry(message: "Ping", level: .debug)
        await store.append(entry)

        let next = await iterator.next()
        let received = try #require(next?.first)
        #expect(received.message == entry.message)
    }

    @Test("maxEntries доступно для UI")
    func exposesMaxEntries() async throws {
        let store = DiagnosticsLogStore.inMemory(maxEntries: 42)
        #expect(store.maxEntries == 42)
    }
}
