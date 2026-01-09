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
        var hasLoadedServersOnce: Bool = false

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
        case serverList(ServerListReducer.Action)
        case path(StackAction<ServerDetailReducer.State, ServerDetailReducer.Action>)
        case openTorrentFile(URL)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
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
                state.hasLoadedServersOnce = true
                guard let pendingURL = state.pendingTorrentFileURL else { return .none }
                guard let targetServer = preferredServer(from: servers, in: state) else {
                    return .none
                }
                state.pendingTorrentFileURL = nil
                return openTorrentFile(pendingURL, in: targetServer, state: &state)

            case .serverList(.serverRepositoryResponse(.failure)):
                state.hasLoadedServersOnce = true
                return .none

            case .serverList(.task):
                guard state.serverList.shouldLoadServersFromRepository == false,
                    state.pendingTorrentFileURL == nil,
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
                if let index = state.serverList.servers.index(id: server.id) {
                    state.serverList.servers[index] = server
                }
                return .none

            case .path(.element(id: let id, action: .delegate(.serverDeleted(let serverID)))):
                state.path[id: id] = nil
                state.serverList.servers.remove(id: serverID)
                return .none

            case .path(.element(id: _, action: .delegate(.torrentSelected))):
                return .none

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
        if let lastID = state.path.ids.last,
            let server = state.path[id: lastID]?.server
        {
            return server
        }
        return preferredServer(from: Array(state.serverList.servers), in: state)
    }

    private func preferredServer(from servers: [ServerConfig], in state: State) -> ServerConfig? {
        if let lastID = state.path.ids.last,
            let server = state.path[id: lastID]?.server
        {
            return server
        }
        return servers.max { lhs, rhs in
            lhs.createdAt < rhs.createdAt
        }
    }

    private func openServerDetail(
        _ server: ServerConfig,
        state: inout State
    ) -> Effect<Action> {
        if let lastID = state.path.ids.last,
            let activeServer = state.path[id: lastID]?.server,
            activeServer.id == server.id
        {
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
        if let lastID = state.path.ids.last,
            let activeServer = state.path[id: lastID]?.server,
            activeServer.id == server.id
        {
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
