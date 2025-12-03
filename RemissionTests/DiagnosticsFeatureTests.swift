import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@MainActor
@Suite("DiagnosticsReducer")
struct DiagnosticsFeatureTests {
    @Test("task загружает логи и получает обновления из observe")
    func taskLoadsAndObservesLogs() async {
        let initial = [
            DomainFixtures.diagnosticsEntry(message: "Initial", level: .info)
        ]
        let update = DomainFixtures.diagnosticsEntry(message: "Updated", level: .error)
        let streamBox = DiagnosticsStreamBox()

        let store = TestStore(
            initialState: DiagnosticsReducer.State()
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = DiagnosticsLogStore(
                load: { _ in initial },
                observe: { _ in
                    AsyncStream { continuation in
                        Task { await streamBox.set(continuation) }
                    }
                },
                append: { _ in },
                clear: {}
            )
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.isLoading = true
            $0.maxEntries = 500
        }

        await store.receive(.logsResponse(.success(initial))) {
            $0.isLoading = false
            $0.entries = IdentifiedArrayOf(uniqueElements: initial)
        }

        await streamBox.yield([update])

        await store.receive(.logsStreamUpdated([update])) {
            $0.entries = IdentifiedArrayOf(uniqueElements: [update])
        }
    }

    @Test("clearTapped очищает буфер и обновляет состояние")
    func clearTapsClearsBuffer() async {
        let initial = [
            DomainFixtures.diagnosticsEntry(message: "Initial", level: .info)
        ]

        let store = TestStore(
            initialState: DiagnosticsReducer.State()
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = .inMemory(initialEntries: initial)
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.isLoading = true
            $0.maxEntries = 500
        }

        let expected = Array(initial.reversed())

        await store.receive(.logsResponse(.success(expected))) {
            $0.isLoading = false
            $0.entries = IdentifiedArrayOf(uniqueElements: expected)
        }

        await store.send(.clearTapped) {
            $0.isLoading = true
        }

        await store.receive(.logsResponse(.success([]))) {
            $0.isLoading = false
            $0.entries = []
        }
    }

    @Test("ошибка загрузки показывает alert и снимает флаг загрузки")
    func loadFailureShowsAlert() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failed

            var errorDescription: String? { "diagnostics failed" }
        }

        let store = TestStore(
            initialState: DiagnosticsReducer.State()
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = DiagnosticsLogStore(
                load: { _ in throw DummyError.failed },
                observe: { _ in AsyncStream { $0.finish() } },
                append: { _ in },
                clear: {}
            )
        }
        store.exhaustivity = .off

        await store.send(.task) {
            $0.isLoading = true
            $0.maxEntries = 500
        }

        await store.receive(.logsResponse(.failure(DummyError.failed))) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState(L10n.tr("diagnostics.alert.loadFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("diagnostics.close"))
                }
            } message: {
                TextState("diagnostics failed")
            }
        }
    }

    @Test("copyEntry формирует безопасный текст и отправляет в буфер")
    func copyEntryCopiesFormattedLog() async throws {
        let entry = DomainFixtures.diagnosticsEntry(
            message: "Transmission RPC error",
            level: .error,
            category: "transmission",
            metadata: [
                "method": "POST",
                "status": "409",
                "elapsed_ms": "120",
                "authorization": "Basic dGVzdDpzZWNyZXQ=",
                "retry_attempt": "1"
            ]
        )

        let copied = LockedValue(initialValue: "")

        let store = TestStore(
            initialState: DiagnosticsReducer.State(entries: [entry])
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.clipboard = ClipboardClient(copy: { value in
                copied.withValue { $0 = value }
            })
        }
        store.exhaustivity = .off

        await store.send(.copyEntry(entry))
        try await Task.sleep(nanoseconds: 5_000_000)

        let result = copied.withValue { $0 }
        #expect(result.contains("Transmission RPC error"))
        #expect(result.contains("status=409"))
        #expect(result.contains("authorization") == false)
        #expect(result.contains("retry_attempt=1"))
    }

    @Test("levelSelected сбрасывает поисковую строку")
    func levelSelectionClearsQuery() async {
        let store = TestStore(
            initialState: DiagnosticsReducer.State(
                entries: [],
                isLoading: false,
                query: "retry",
                selectedLevel: nil
            )
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = .inMemory()
        }
        store.exhaustivity = .off

        await store.send(.levelSelected(.error)) {
            $0.selectedLevel = .error
            $0.query = ""
        }
    }

    @Test("clearTapped очищает локально и показывает алерт при ошибке загрузки")
    func clearTappedKeepsStateEmptyOnLoadFailure() async {
        enum DummyError: Error, LocalizedError, Equatable {
            case failed
            var errorDescription: String? { "clear load failed" }
        }

        let initial = [
            DomainFixtures.diagnosticsEntry(message: "Initial", level: .info)
        ]

        let store = TestStore(
            initialState: DiagnosticsReducer.State(
                entries: IdentifiedArrayOf(uniqueElements: initial)
            )
        ) {
            DiagnosticsReducer()
        } withDependencies: {
            $0.diagnosticsLogStore = DiagnosticsLogStore(
                load: { _ in throw DummyError.failed },
                observe: { _ in AsyncStream { $0.finish() } },
                append: { _ in },
                clear: {}
            )
        }
        store.exhaustivity = .off

        await store.send(.clearTapped) {
            $0.isLoading = true
            $0.entries = []
        }

        await store.receive(.logsResponse(.failure(DummyError.failed))) {
            $0.isLoading = false
            $0.alert = AlertState {
                TextState(L10n.tr("diagnostics.alert.loadFailed.title"))
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState(L10n.tr("diagnostics.close"))
                }
            } message: {
                TextState("clear load failed")
            }
        }
    }
}

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(initialValue value: Value) {
        self.value = value
    }

    func withValue<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

private actor DiagnosticsStreamBox {
    private var continuation: AsyncStream<[DiagnosticsLogEntry]>.Continuation?

    func set(_ continuation: AsyncStream<[DiagnosticsLogEntry]>.Continuation) {
        self.continuation = continuation
    }

    func yield(_ entries: [DiagnosticsLogEntry]) {
        continuation?.yield(entries)
    }
}
