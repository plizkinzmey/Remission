import ComposableArchitecture
import Foundation

@Reducer
struct DiagnosticsReducer {
    @ObservableState
    struct State: Equatable {
        var entries: IdentifiedArrayOf<DiagnosticsLogEntry> = []
        var isLoading: Bool = false
        var query: String = ""
        var selectedLevel: AppLogLevel?
        @Presents var alert: AlertState<AlertAction>?

        var filter: DiagnosticsLogFilter {
            DiagnosticsLogFilter(level: selectedLevel, searchText: query)
        }
    }

    enum Action: Equatable {
        case task
        case teardown
        case clearTapped
        case levelSelected(AppLogLevel?)
        case queryChanged(String)
        case logsResponse(TaskResult<[DiagnosticsLogEntry]>)
        case logsStreamUpdated([DiagnosticsLogEntry])
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum Delegate: Equatable {
        case closeRequested
    }

    @Dependency(\.diagnosticsLogStore) var diagnosticsLogStore

    private enum CancelID {
        case observe
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                let filter = state.filter
                return .merge(
                    loadLogs(filter: filter),
                    observeLogs(filter: filter)
                )

            case .teardown:
                return .cancel(id: CancelID.observe)

            case .queryChanged(let value):
                state.query = value
                return restartObservation(filter: state.filter)

            case .levelSelected(let level):
                state.selectedLevel = level
                return restartObservation(filter: state.filter)

            case .logsResponse(.success(let entries)):
                state.isLoading = false
                state.entries = IdentifiedArrayOf(uniqueElements: entries)
                return .none

            case .logsResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("Не удалось загрузить логи")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Закрыть")
                    }
                } message: {
                    TextState(describe(error))
                }
                return .none

            case .logsStreamUpdated(let entries):
                state.entries = IdentifiedArrayOf(uniqueElements: entries)
                return .none

            case .clearTapped:
                state.isLoading = true
                let filter = state.filter
                return .run { send in
                    await send(
                        .logsResponse(
                            TaskResult {
                                try await diagnosticsLogStore.clear()
                                return try await diagnosticsLogStore.load(filter)
                            }
                        )
                    )
                }

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func loadLogs(filter: DiagnosticsLogFilter) -> Effect<Action> {
        .run { send in
            await send(
                .logsResponse(
                    TaskResult {
                        try await diagnosticsLogStore.load(filter)
                    }
                )
            )
        }
    }

    private func observeLogs(filter: DiagnosticsLogFilter) -> Effect<Action> {
        .run { send in
            let stream = await diagnosticsLogStore.observe(filter)
            for await entries in stream {
                await send(.logsStreamUpdated(entries))
            }
        }
        .cancellable(id: CancelID.observe, cancelInFlight: true)
    }

    private func restartObservation(filter: DiagnosticsLogFilter) -> Effect<Action> {
        .merge(
            .cancel(id: CancelID.observe),
            loadLogs(filter: filter),
            observeLogs(filter: filter)
        )
    }

    private func describe(_ error: Error) -> String {
        guard let localized = error as? LocalizedError,
            let message = localized.errorDescription,
            message.isEmpty == false
        else {
            return String(describing: error)
        }
        return message
    }
}
