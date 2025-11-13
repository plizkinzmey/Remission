import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct TorrentListReducer {
    @ObservableState
    struct State: Equatable {
        var connectionEnvironment: ServerConnectionEnvironment?
        var torrents: IdentifiedArrayOf<Torrent> = []
        var isLoading: Bool = false
        var errorMessage: String?
    }

    enum Action: Equatable {
        case connectionAvailable(ServerConnectionEnvironment)
        case connectionLost
        case refreshButtonTapped
        case pollingTick
        case torrentsResponse(TaskResult<[Torrent]>)
        case torrentTapped(Torrent.Identifier)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case torrentSelected(Torrent.Identifier)
    }

    @Dependency(\.appClock) var appClock
    @Dependency(\.torrentListPollingInterval) var pollingInterval

    private enum CancelID {
        case fetch
        case polling
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .connectionAvailable(let environment):
                state.connectionEnvironment = environment
                state.errorMessage = nil
                return .merge(
                    fetchTorrents(state: &state),
                    schedulePolling(state: state)
                )

            case .connectionLost:
                state.connectionEnvironment = nil
                state.torrents.removeAll()
                state.isLoading = false
                state.errorMessage = nil
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .cancel(id: CancelID.polling)
                )

            case .refreshButtonTapped:
                return fetchTorrents(state: &state)

            case .pollingTick:
                guard state.connectionEnvironment != nil else {
                    return .cancel(id: CancelID.polling)
                }
                return .merge(
                    fetchTorrents(state: &state),
                    schedulePolling(state: state)
                )

            case .torrentsResponse(.success(let torrents)):
                state.isLoading = false
                state.errorMessage = nil
                state.torrents = IdentifiedArrayOf(uniqueElements: torrents)
                return .none

            case .torrentsResponse(.failure(let error)):
                state.isLoading = false
                state.errorMessage = describe(error)
                return .none

            case .torrentTapped(let id):
                return .send(.delegate(.torrentSelected(id)))

            case .delegate:
                return .none
            }
        }
    }

    private func fetchTorrents(state: inout State) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.isLoading = false
            return .none
        }

        state.isLoading = true
        state.errorMessage = nil

        return .run { [environment] send in
            await send(
                .torrentsResponse(
                    TaskResult {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.torrentRepository) var repository: TorrentRepository
                            return try await repository.fetchList()
                        }
                    }
                )
            )
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }

    private func schedulePolling(state: State) -> Effect<Action> {
        guard let pollingInterval, state.connectionEnvironment != nil else {
            return .cancel(id: CancelID.polling)
        }

        return .run { send in
            let clock = appClock.clock()
            try await clock.sleep(for: pollingInterval)
            await send(.pollingTick)
        }
        .cancellable(id: CancelID.polling, cancelInFlight: true)
    }

    private func describe(_ error: Error) -> String {
        if let localized = error as? LocalizedError,
            let description = localized.errorDescription,
            description.isEmpty == false
        {
            return description
        }
        return String(describing: error)
    }
}

private enum TorrentListPollingIntervalKey: DependencyKey {
    static let liveValue: Duration? = .seconds(10)
    static let previewValue: Duration? = .seconds(5)
    static let testValue: Duration? = nil
}

extension DependencyValues {
    var torrentListPollingInterval: Duration? {
        get { self[TorrentListPollingIntervalKey.self] }
        set { self[TorrentListPollingIntervalKey.self] = newValue }
    }
}
