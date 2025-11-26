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
