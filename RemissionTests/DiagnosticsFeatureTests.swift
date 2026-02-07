import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Diagnostics Feature Tests")
@MainActor
struct DiagnosticsFeatureTests {

    @Test("Task загружает логи и настраивает пагинацию")
    func testTaskLoadsLogs() async {
        // Проверяем, что task загружает логи и выставляет visibleCount.
        let entries = [
            DiagnosticsLogEntry(
                timestamp: Date(timeIntervalSince1970: 1),
                level: .info,
                message: "Message",
                category: "network"
            )
        ]

        let store = TestStore(initialState: DiagnosticsReducer.State()) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore.load = { @Sendable _ in entries }
            $0.diagnosticsLogStore.observe = { @Sendable _ in
                AsyncStream<DiagnosticsLogStore.StreamEvent> { $0.finish() }
            }
            $0.diagnosticsLogStore.maxEntries = 250
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.isLoading = true
            $0.maxEntries = 250
            $0.visibleCount = $0.pageSize
            $0.isLive = true
        }

        await store.receive(.logsResponse(.success(entries))) {
            $0.isLoading = false
            $0.entries = IdentifiedArrayOf(uniqueElements: entries)
            $0.visibleCount = 1
        }
    }

    @Test("QueryChanged перезапускает загрузку")
    func testQueryChangedReloads() async {
        // Проверяем, что смена query вызывает загрузку и обновляет entries.
        let entries = [
            DiagnosticsLogEntry(
                timestamp: Date(timeIntervalSince1970: 2),
                level: .error,
                message: "Error",
                category: "network"
            )
        ]

        let store = TestStore(initialState: DiagnosticsReducer.State()) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore.load = { @Sendable _ in entries }
            $0.diagnosticsLogStore.observe = { @Sendable _ in
                AsyncStream<DiagnosticsLogStore.StreamEvent> { $0.finish() }
            }
        }
        store.exhaustivity = .off

        await store.send(.queryChanged("error")) {
            $0.query = "error"
        }

        await store.receive(.logsResponse(.success(entries))) {
            $0.isLoading = false
            $0.entries = IdentifiedArrayOf(uniqueElements: entries)
            $0.visibleCount = 1
        }
    }

    @Test("Ошибка загрузки показывает alert")
    func testLogsResponseFailureShowsAlert() async {
        // Проверяем, что ошибка загрузки формирует alert.
        let error = TestError(message: "Ошибка")
        let store = TestStore(initialState: DiagnosticsReducer.State()) {
            DiagnosticsReducer()
        }

        await store.send(.logsResponse(.failure(error))) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState(L10n.tr("diagnostics.alert.loadFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("diagnostics.close"))
                }
            } message: {
                TextState(error.message)
            }
        }
    }

    @Test("ToggleLive выключает live режим")
    func testToggleLiveDisablesLive() async {
        // Проверяем, что toggleLive меняет флаг и останавливает стрим.
        var state = DiagnosticsReducer.State()
        state.isLive = true

        let store = TestStore(initialState: state) {
            DiagnosticsReducer()
        }

        await store.send(.toggleLive) {
            $0.isLive = false
        }
    }

    @Test("CopyEntry пишет в clipboard")
    func testCopyEntryCopiesToClipboard() async {
        // Проверяем, что copyEntry отправляет форматированный текст в clipboard.
        let recorder = ClipboardRecorder()
        let entry = DiagnosticsLogEntry(
            timestamp: Date(timeIntervalSince1970: 3),
            level: .debug,
            message: "Ping",
            category: "network"
        )

        let store = TestStore(initialState: DiagnosticsReducer.State()) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.clipboard.copy = { @Sendable text in
                await recorder.record(text)
            }
        }

        await store.send(.copyEntry(entry))

        let copied = await recorder.waitForText()
        #expect(copied.contains("Ping"))
    }
}

private actor ClipboardRecorder {
    private var text: String?
    private var continuations: [CheckedContinuation<String, Never>] = []

    func record(_ value: String) {
        text = value
        for continuation in continuations {
            continuation.resume(returning: value)
        }
        continuations.removeAll()
    }

    func waitForText() async -> String {
        if let text {
            return text
        }
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }
}

private struct TestError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}
