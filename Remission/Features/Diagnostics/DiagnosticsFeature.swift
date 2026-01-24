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
        var maxEntries: Int?
        var pageSize: Int = 100
        var visibleCount: Int = 100
        var viewMode: DiagnosticsViewMode = .list
        var isLive: Bool = true
        @Presents var alert: AlertState<AlertAction>?

        var filter: DiagnosticsLogFilter {
            DiagnosticsLogFilter(level: selectedLevel, searchText: query)
        }

        var visibleEntries: IdentifiedArrayOf<DiagnosticsLogEntry> {
            let slice = entries.prefix(visibleCount)
            return IdentifiedArrayOf(uniqueElements: Array(slice))
        }
    }

    enum Action: Equatable {
        case task
        case teardown
        case clearTapped
        case levelSelected(AppLogLevel?)
        case queryChanged(String)
        case viewModeChanged(DiagnosticsViewMode)
        case toggleLive
        case copyEntry(DiagnosticsLogEntry)
        case logsResponse(TaskResult<[DiagnosticsLogEntry]>)
        case logsStreamUpdated([DiagnosticsLogEntry])
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
        case shareAllTapped
        case loadMoreIfNeeded
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum Delegate: Equatable {
        case closeRequested
    }

    @Dependency(\.diagnosticsLogStore) var diagnosticsLogStore
    @Dependency(\.clipboard) var clipboard

    private enum CancelID {
        case observe
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                state.maxEntries = diagnosticsLogStore.maxEntries
                state.visibleCount = state.pageSize
                state.isLive = true
                let filter = state.filter
                return .merge(
                    loadLogs(filter: filter),
                    observeLogs(filter: filter)
                )

            case .teardown:
                return .cancel(id: CancelID.observe)

            case .toggleLive:
                state.isLive.toggle()
                if state.isLive {
                    // Resume: Clear old values and start fresh stream
                    state.entries.removeAll()
                    state.visibleCount = state.pageSize
                    return observeLogs(filter: state.filter)
                } else {
                    // Pause: Stop stream
                    return .cancel(id: CancelID.observe)
                }

            case .queryChanged(let value):
                state.query = value
                return restartObservation(state: state)

            case .levelSelected(let level):
                state.selectedLevel = level
                state.query = ""
                return restartObservation(state: state)

            case .viewModeChanged(let mode):
                state.viewMode = mode
                return .none

            case .shareAllTapped:
                let entries = state.entries.elements
                return .run { _ in
                    let text = DiagnosticsLogFormatter.copyText(for: entries)
                    await clipboard.copy(text)
                }

            case .copyEntry(let entry):
                return .run { _ in
                    await clipboard.copy(DiagnosticsLogFormatter.copyText(for: entry))
                }

            case .logsResponse(.success(let entries)):
                state.isLoading = false
                state.entries = IdentifiedArrayOf(uniqueElements: entries)
                if state.entries.isEmpty {
                    state.visibleCount = 0
                } else {
                    state.visibleCount = max(
                        1,
                        min(
                            max(state.visibleCount, state.pageSize),
                            state.entries.count
                        )
                    )
                }
                return .none

            case .logsResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState(L10n.tr("diagnostics.alert.loadFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("diagnostics.close"))
                    }
                } message: {
                    TextState(describe(error))
                }
                return .none

            case .logsStreamUpdated(let entries):
                state.entries = IdentifiedArrayOf(uniqueElements: entries)
                if state.entries.isEmpty {
                    state.visibleCount = 0
                } else {
                    state.visibleCount = max(
                        1,
                        min(
                            max(state.visibleCount, state.pageSize),
                            state.entries.count
                        )
                    )
                }
                return .none

            case .clearTapped:
                state.isLoading = true
                state.entries.removeAll()
                let filter = state.filter
                return .run { send in
                    do {
                        try await diagnosticsLogStore.clear()
                        let entries = try await diagnosticsLogStore.load(filter)
                        await send(.logsResponse(.success(entries)))
                    } catch {
                        await send(.logsResponse(.failure(error)))
                    }
                }

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .loadMoreIfNeeded:
                guard state.entries.count > state.visibleCount else { return .none }
                state.visibleCount = min(state.visibleCount + state.pageSize, state.entries.count)
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

    private func restartObservation(state: State) -> Effect<Action> {
        let filter = state.filter
        if state.isLive {
            return .concatenate(
                .cancel(id: CancelID.observe),
                loadLogs(filter: filter),
                observeLogs(filter: filter)
            )
        } else {
            // If paused, just reload history to match filter, do not start stream
            return loadLogs(filter: filter)
        }
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
