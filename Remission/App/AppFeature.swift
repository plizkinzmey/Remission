import ComposableArchitecture
import Foundation

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var version: AppStateVersion
        var serverList: ServerListReducer.State
        var path: StackState<ServerDetailReducer.State>
        var pendingTorrentFileURL: URL?
        #if os(iOS)
            var startup: StartupState = .init()
        #endif

        init(
            version: AppStateVersion = .latest,
            serverList: ServerListReducer.State = .init(),
            path: StackState<ServerDetailReducer.State> = .init()
        ) {
            self.version = version
            self.serverList = serverList
            self.path = path
        }
    }

    enum Action: Equatable {
        case task
        case startupTimerElapsed
        case serverList(ServerListReducer.Action)
        case path(StackAction<ServerDetailReducer.State, ServerDetailReducer.Action>)
        case openTorrentFile(URL)
    }

    @Dependency(\.appClock) var appClock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                var effects: [Effect<Action>] = [
                    .send(.serverList(.task))
                ]
                #if os(iOS)
                    if state.startup.shouldScheduleTimer {
                        state.startup.isTimerScheduled = true
                        effects.append(
                            .run { send in
                                let clock = appClock.clock()
                                do {
                                    try await clock.sleep(for: StartupState.minimumDuration)
                                    await send(.startupTimerElapsed)
                                } catch is CancellationError {
                                    return
                                }
                            }
                            .cancellable(id: StartupCancellationID.timer, cancelInFlight: true)
                        )
                    }
                #endif
                return .merge(effects)

            case .startupTimerElapsed:
                #if os(iOS)
                    state.startup.hasPresentedOnce = true
                    state.startup.minDurationElapsed = true
                    state.startup.isTimerScheduled = false
                #endif
                return .none

            case .openTorrentFile(let url):
                guard url.isFileURL else { return .none }
                guard url.pathExtension.lowercased() == "torrent" else { return .none }

                if let targetServer = preferredServer(in: state) {
                    return openTorrentFile(url, in: targetServer, state: &state)
                }

                state.pendingTorrentFileURL = url
                if state.serverList.isLoading == false {
                    return .merge(
                        .send(.serverList(.task)),
                        .send(.serverList(.addButtonTapped))
                    )
                }
                return .send(.serverList(.addButtonTapped))

            case .serverList(.delegate(.serverSelected(let server))):
                if let pendingURL = state.pendingTorrentFileURL {
                    state.pendingTorrentFileURL = nil
                    return openTorrentFile(pendingURL, in: server, state: &state)
                }
                return openServerDetail(server, state: &state)

            case .serverList(.delegate(.serverCreated(let server))):
                if let pendingURL = state.pendingTorrentFileURL {
                    state.pendingTorrentFileURL = nil
                    return openTorrentFile(pendingURL, in: server, state: &state)
                }
                return openServerDetail(server, state: &state)

            case .serverList(.serverRepositoryResponse(.success(let servers))):
                guard let pendingURL = state.pendingTorrentFileURL else { return .none }
                guard let targetServer = preferredServer(from: servers, in: state) else {
                    return .none
                }
                state.pendingTorrentFileURL = nil
                return openTorrentFile(pendingURL, in: targetServer, state: &state)

            case .serverList(.serverRepositoryResponse(.failure)):
                return .none

            case .serverList(.task):
                guard state.pendingTorrentFileURL == nil,
                    state.path.isEmpty,
                    state.serverList.servers.count == 1,
                    let server = state.serverList.servers.first
                else {
                    return .none
                }
                return openServerDetail(server, state: &state)

            case .serverList:
                return .none

            case .path(.element(id: _, action: .delegate(.serverUpdated(let server)))):
                state.serverList.servers[id: server.id] = server
                return .none

            case .path(.element(id: let id, action: .delegate(.serverDeleted(let serverID)))):
                state.path[id: id] = nil
                state.serverList.servers.remove(id: serverID)
                return .none

            case .path(.element(id: _, action: .delegate(.torrentSelected))):
                return .none

            case .path(
                .element(id: let detailID, action: .connectionResponse(.success(let response)))):
                guard let serverID = state.path[id: detailID]?.server.id else { return .none }
                return .send(
                    .serverList(
                        .connectionProbeResponse(
                            serverID,
                            .success(.init(handshake: response.handshake))
                        )
                    )
                )

            case .path(.element(id: let detailID, action: .connectionResponse(.failure(let error)))):
                guard let serverID = state.path[id: detailID]?.server.id else { return .none }
                return .send(.serverList(.connectionProbeResponse(serverID, .failure(error))))

            case .path(
                .element(id: let detailID, action: .torrentList(.storageUpdated(let summary)))):
                guard let serverID = state.path[id: detailID]?.server.id, let summary else {
                    return .none
                }
                return .send(.serverList(.storageResponse(serverID, .success(summary))))

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            ServerDetailReducer()
        }

        Scope(state: \.serverList, action: \.serverList) {
            ServerListReducer()
        }
    }

    private func preferredServer(in state: State) -> ServerConfig? {
        let lastServer = state.path.ids.last.flatMap { state.path[id: $0]?.server }
        if let lastServer { return lastServer }
        return preferredServer(from: Array(state.serverList.servers), in: state)
    }

    private func preferredServer(from servers: [ServerConfig], in state: State) -> ServerConfig? {
        let lastServer = state.path.ids.last.flatMap { state.path[id: $0]?.server }
        if let lastServer { return lastServer }
        return servers.max { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
    }

    private func openServerDetail(
        _ server: ServerConfig,
        state: inout State
    ) -> Effect<Action> {
        let activeServer = state.path.ids.last.flatMap { state.path[id: $0]?.server }
        if activeServer?.id == server.id {
            return .none
        }
        state.path.append(ServerDetailReducer.State(server: server))
        return .none
    }

    private func openTorrentFile(
        _ url: URL,
        in server: ServerConfig,
        state: inout State
    ) -> Effect<Action> {
        let activeServer = state.path.ids.last.flatMap { state.path[id: $0]?.server }
        if activeServer?.id == server.id {
            guard let lastID = state.path.ids.last else { return .none }
            return .send(
                .path(.element(id: lastID, action: .fileImportResult(.success(url))))
            )
        }

        state.path.append(ServerDetailReducer.State(server: server))
        guard let targetID = state.path.ids.last else { return .none }
        return .send(
            .path(.element(id: targetID, action: .fileImportResult(.success(url))))
        )
    }
}

#if os(iOS)
    struct StartupState: Equatable {
        static let minimumDuration: Duration = .seconds(4)

        var hasPresentedOnce: Bool = false
        var minDurationElapsed: Bool = false
        var isTimerScheduled: Bool = false

        var shouldScheduleTimer: Bool {
            hasPresentedOnce == false && isTimerScheduled == false
        }
    }

    private enum StartupCancellationID {
        case timer
    }
#endif
