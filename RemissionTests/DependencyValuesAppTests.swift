import Dependencies
import Foundation
import Testing

@testable import Remission

@Suite("DependencyValues.app*")
struct DependencyValuesAppTests {
    @Test("appTest использует noop-логгер и рабочий inMemory diagnostics store")
    func appTestProvidesNoopLoggerAndInMemoryDiagnostics() async throws {
        // Это базовый инвариант для всех unit-тестов:
        // логгер не должен шуметь, но diagnostics store должен быть функциональным.
        let dependencies = DependencyValues.appTest()

        #expect(dependencies.appLogger.isNoop)

        let entry = DiagnosticsLogEntry(
            timestamp: Date(timeIntervalSince1970: 1),
            level: .info,
            message: "test entry",
            category: "tests"
        )
        await dependencies.diagnosticsLogStore.append(entry)

        let loaded = try await dependencies.diagnosticsLogStore.load(.init())
        #expect(loaded.count == 1)
        #expect(loaded.first?.message == "test entry")
    }

    @Test("appDefault связывает appLogger с diagnosticsLogStore через sink")
    func appDefaultConnectsLoggerToDiagnosticsStore() async throws {
        // Этот тест фиксирует wiring: запись через appLogger должна попасть в diagnostics store.
        // Важно для экрана Diagnostics и для отладки проблем на реальных устройствах.
        let dependencies = DependencyValues.appDefault()

        dependencies.appLogger.warning("wired log", metadata: ["source": "test"])

        let entries = try await waitForEntries(in: dependencies.diagnosticsLogStore, minCount: 1)

        #expect(entries.first?.message == "wired log")
        #expect(entries.first?.level == .warning)
    }
}

private func waitForEntries(
    in store: DiagnosticsLogStore,
    minCount: Int,
    attempts: Int = 20,
    delay: Duration = .milliseconds(25)
) async throws -> [DiagnosticsLogEntry] {
    for _ in 0..<attempts {
        let snapshot = try await store.load(.init())
        if snapshot.count >= minCount {
            return snapshot
        }
        try await Task.sleep(for: delay)
    }

    Issue.record("DiagnosticsLogStore не получил ожидаемое количество записей")
    return try await store.load(.init())
}
