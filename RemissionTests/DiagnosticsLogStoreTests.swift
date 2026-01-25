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

    @Test("observe немедленно отдаёт snapshot и затем обновления")
    func observeYieldsInitialSnapshotThenUpdates() async throws {
        // Контракт observe: сразу yield текущего состояния,
        // затем yield при каждом append/clear.
        let store = DiagnosticsLogStore.inMemory(maxEntries: 5)
        let stream = await store.observe(.init())
        var iterator = stream.makeAsyncIterator()

        let initial = try #require(await iterator.next())
        #expect(initial.isEmpty)

        await store.append(makeEntry(message: "first", level: .info))

        let updated = try #require(await iterator.next())
        #expect(updated.map(\.message) == ["first"])
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
