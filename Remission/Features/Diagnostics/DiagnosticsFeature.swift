import ComposableArchitecture
import Foundation

@Reducer
struct DiagnosticsReducer {
    @ObservableState
    struct State: Equatable {
        var entries: IdentifiedArrayOf<DiagnosticsLogEntry> = []
        var isLoading: Bool = false
        var query: String = ""
        // Default to Info for the initial diagnostics view.
        var selectedLevel: AppLogLevel? = .info
        var maxEntries: Int?
        var pageSize: Int = 100
        var visibleCount: Int = 100
        var viewMode: DiagnosticsViewMode = .list
        var isLive: Bool = true
        var isAtTop: Bool = true
        var pendingEntries: [DiagnosticsLogEntry] = []
        var scrollToLatestRequest: Int = 0
        @Presents var alert: AlertState<AlertAction>?

        var filter: DiagnosticsLogFilter {
            DiagnosticsLogFilter(level: selectedLevel, searchText: query)
        }

        var pendingCount: Int { pendingEntries.count }

        var visibleEntries: [DiagnosticsLogEntry] {
            Array(entries.prefix(visibleCount))
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
        case topRowVisibilityChanged(Bool)
        case jumpToLatestTapped
        case copyEntry(DiagnosticsLogEntry)
        case logsResponse(TaskResult<[DiagnosticsLogEntry]>)
        case logsStreamEvent(DiagnosticsLogStore.StreamEvent)
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
                state.isAtTop = true
                state.pendingEntries.removeAll()
                let filter = state.filter
                return .concatenate(
                    loadLogs(filter: filter),
                    observeLogs(filter: filter)
                )

            case .teardown:
                return .cancel(id: CancelID.observe)

            case .toggleLive:
                state.isLive.toggle()
                state.pendingEntries.removeAll()
                if state.isLive {
                    // Resume: Clear old values and start fresh stream
                    state.entries.removeAll()
                    state.visibleCount = state.pageSize
                    state.isAtTop = true
                    return .concatenate(
                        loadLogs(filter: state.filter),
                        observeLogs(filter: state.filter)
                    )
                } else {
                    // Pause: Stop stream
                    return .cancel(id: CancelID.observe)
                }

            case .topRowVisibilityChanged(let isVisible):
                state.isAtTop = isVisible
                if isVisible, state.isLive, state.pendingEntries.isEmpty == false {
                    let pending = state.pendingEntries
                    state.pendingEntries.removeAll()
                    // Insert oldest-first so newest ends up at the very top.
                    for entry in pending.reversed() {
                        state.entries.insert(entry, at: 0)
                    }
                    if let max = state.maxEntries, state.entries.count > max {
                        state.entries.removeLast(state.entries.count - max)
                    }
                    state.visibleCount = max(
                        1,
                        min(max(state.visibleCount, state.pageSize), state.entries.count)
                    )
                }
                return .none

            case .jumpToLatestTapped:
                guard state.isLive else { return .none }
                if state.pendingEntries.isEmpty == false {
                    let pending = state.pendingEntries
                    state.pendingEntries.removeAll()
                    // Insert oldest-first so newest ends up at the very top.
                    for entry in pending.reversed() {
                        state.entries.insert(entry, at: 0)
                    }
                    if let max = state.maxEntries, state.entries.count > max {
                        state.entries.removeLast(state.entries.count - max)
                    }
                }
                state.scrollToLatestRequest += 1
                state.isAtTop = true
                return .none

            case .queryChanged(let value):
                state.query = value
                state.pendingEntries.removeAll()
                return restartObservation(state: state)

            case .levelSelected(let level):
                state.selectedLevel = level
                state.query = ""
                state.pendingEntries.removeAll()
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
                state.pendingEntries.removeAll()
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

            case .logsStreamEvent(let event):
                guard state.isLive else { return .none }
                switch event {
                case .cleared:
                    state.entries.removeAll()
                    state.pendingEntries.removeAll()
                    state.visibleCount = 0

                case .dropped(let ids):
                    for id in ids {
                        state.entries.remove(id: id)
                    }
                    if state.entries.isEmpty {
                        state.visibleCount = 0
                    } else {
                        state.visibleCount = max(
                            1,
                            min(max(state.visibleCount, state.pageSize), state.entries.count)
                        )
                    }

                case .appended(let entry):
                    if state.isAtTop {
                        state.entries.insert(entry, at: 0)
                        if let max = state.maxEntries, state.entries.count > max {
                            state.entries.removeLast(state.entries.count - max)
                        }
                        state.visibleCount = max(
                            1,
                            min(max(state.visibleCount, state.pageSize), state.entries.count)
                        )
                    } else {
                        state.pendingEntries.insert(entry, at: 0)
                        if let max = state.maxEntries, state.pendingEntries.count > max {
                            state.pendingEntries.removeLast(state.pendingEntries.count - max)
                        }
                    }
                }
                return .none

            case .clearTapped:
                state.isLoading = true
                state.entries.removeAll()
                state.pendingEntries.removeAll()
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
            for await event in stream {
                await send(.logsStreamEvent(event))
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
