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
        var pendingConnection: PendingConnection?

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

    struct PendingConnection: Equatable {
        var server: ServerConfig
    }

    enum Action: Equatable {
        case serverList(ServerListReducer.Action)
        case path(StackAction<ServerDetailReducer.State, ServerDetailReducer.Action>)
        case openTorrentFile(URL)
        case connectionPreparationResponse(
            UUID,
            TaskResult<ServerDetailReducer.ConnectionResponse>
        )
    }

    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.serverConnectionEnvironmentFactory) var serverConnectionEnvironmentFactory

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
                state.pendingConnection = PendingConnection(server: server)
                return prepareConnection(server)

            case .serverList(.delegate(.serverCreated(let server))):
                if let pendingURL = state.pendingTorrentFileURL {
                    state.pendingTorrentFileURL = nil
                    return openTorrentFile(pendingURL, in: server, state: &state)
                }
                state.pendingConnection = PendingConnection(server: server)
                return prepareConnection(server)

            case .serverList(.serverRepositoryResponse(.success(let servers))):
                guard let pendingURL = state.pendingTorrentFileURL else { return .none }
                guard let targetServer = preferredServer(from: servers, in: state) else {
                    return .none
                }
                state.pendingTorrentFileURL = nil
                return openTorrentFile(pendingURL, in: targetServer, state: &state)

            case .serverList:
                return .none

            case .connectionPreparationResponse(let id, .success(let response)):
                guard let pending = state.pendingConnection, pending.server.id == id else {
                    return .none
                }
                state.pendingConnection = nil
                let environment = response.environment.updatingRPCVersion(
                    response.handshake.rpcVersion
                )
                var detailState = ServerDetailReducer.State(server: pending.server)
                detailState.connectionEnvironment = environment
                detailState.connectionState.phase = .ready(
                    .init(
                        fingerprint: environment.fingerprint,
                        handshake: response.handshake
                    )
                )
                detailState.torrentList.connectionEnvironment = environment
                detailState.torrentList.cacheKey = environment.cacheKey
                state.path.append(detailState)
                return .none

            case .connectionPreparationResponse(let id, .failure(let error)):
                guard state.pendingConnection?.server.id == id else { return .none }
                state.pendingConnection = nil
                state.serverList.alert = AlertState {
                    TextState(L10n.tr("serverDetail.alert.connectionFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(describe(error))
                }
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

    private func prepareConnection(
        _ server: ServerConfig
    ) -> Effect<Action> {
        .run { send in
            await send(
                .connectionPreparationResponse(
                    server.id,
                    TaskResult {
                        let environment = try await serverConnectionEnvironmentFactory.make(server)
                        let handshake =
                            try await environment.dependencies.transmissionClient.performHandshake()
                        return .init(environment: environment, handshake: handshake)
                    }
                )
            )
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
