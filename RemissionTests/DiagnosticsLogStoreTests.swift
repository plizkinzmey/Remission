import Foundation
import Testing

@testable import Remission

@Suite("DiagnosticsLogStore")
struct DiagnosticsLogStoreTests {
    @Test("inMemory соблюдает maxEntries и порядок «сначала новые»")
    func inMemoryRespectsMaxEntriesAndOrdering() async throws {
        // Буфер должен работать как «кольцо»: хранить только последние N записей
        // и отдавать их в порядке от новых к старым.
        let store = DiagnosticsLogStore.inMemory(maxEntries: 2)

        await store.append(makeEntry(message: "one", level: .info))
        await store.append(makeEntry(message: "two", level: .warning))
        await store.append(makeEntry(message: "three", level: .error))

        let entries = try await store.load(.init())

        #expect(entries.count == 2)
        #expect(entries.map(\.message) == ["three", "two"])
    }

    @Test("Фильтрация по уровню и searchText применяется поверх snapshot")
    func filterAppliesLevelAndSearchText() async throws {
        // Этот тест покрывает DiagnosticsLogFilter.matches через публичный API store.
        let seed: [DiagnosticsLogEntry] = [
            makeEntry(message: "RPC handshake", level: .info, category: "rpc"),
            makeEntry(message: "RPC failed", level: .error, category: "rpc"),
            makeEntry(message: "UI refreshed", level: .debug, category: "ui")
        ]
        let store = DiagnosticsLogStore.inMemory(initialEntries: seed, maxEntries: 10)

        let filter = DiagnosticsLogFilter(level: .error, searchText: "rpc")
        let entries = try await store.load(filter)

        #expect(entries.count == 1)
        #expect(entries.first?.message == "RPC failed")
        #expect(entries.first?.level == .error)
    }

    @Test("observe отдаёт события (appended/cleared) вместо полных snapshot-ов")
    func observeYieldsEvents() async throws {
        // Контракт observe: поток событий, чтобы UI мог обновляться инкрементально
        // (без пересоздания всего массива записей при каждом append).
        let store = DiagnosticsLogStore.inMemory(maxEntries: 5)
        let stream = await store.observe(.init())
        var iterator = stream.makeAsyncIterator()

        await store.append(makeEntry(message: "first", level: .info))

        let firstEvent = try #require(await iterator.next())
        switch firstEvent {
        case .appended(let entry):
            #expect(entry.message == "first")
        case .cleared, .dropped:
            #expect(Bool(false))
        }

        try await store.clear()

        let clearEvent = try #require(await iterator.next())
        switch clearEvent {
        case .cleared:
            break
        case .appended, .dropped:
            #expect(Bool(false))
        }
    }
}

private func makeEntry(
    message: String,
    level: AppLogLevel,
    category: String = "test",
    timestamp: Date = Date(timeIntervalSince1970: 0)
) -> DiagnosticsLogEntry {
    DiagnosticsLogEntry(
        timestamp: timestamp,
        level: level,
        message: message,
        category: category,
        metadata: [:]
    )
}
