import ComposableArchitecture
import Foundation

#if os(iOS)
    import UIKit
#endif

@Reducer
struct AppReducer {
    @ObservableState
    struct State: Equatable {
        var version: AppStateVersion
        var serverList: ServerListReducer.State
        var path: StackState<Path.State>
        var pendingTorrentFileURL: URL?
        @Presents var trustPrompt: ServerTrustPromptReducer.State?
        var trustPromptQueue: [TransmissionTrustPrompt] = []
        #if os(iOS)
            var startup: StartupState = .init()
            var backgroundFetchCompletion: BackgroundFetchCompletion?
        #endif

        init(
            version: AppStateVersion = .latest,
            serverList: ServerListReducer.State = .init(),
            path: StackState<Path.State> = .init()
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
        case path(StackAction<Path.State, Path.Action>)
        case openTorrentFile(URL)
        case trustPromptReceived(TransmissionTrustPrompt)
        case trustPrompt(PresentationAction<ServerTrustPromptReducer.Action>)
        #if os(iOS)
            case backgroundFetch(BackgroundFetchCompletion)
        #endif
    }

    @Dependency(\.appClock) var appClock
    @Dependency(\.appLogger) var logger
    @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                var effects: [Effect<Action>] = [
                    .send(.serverList(.task)),
                    .run { send in
                        let stream = await trustPromptCenter.observe()
                        for await prompt in stream {
                            await send(.trustPromptReceived(prompt))
                        }
                    }
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

            case .trustPromptReceived(let prompt):
                if state.trustPrompt == nil {
                    state.trustPrompt = ServerTrustPromptReducer.State(prompt: prompt)
                } else {
                    // Multiple concurrent URLSession challenges are possible; queue them so none hang.
                    state.trustPromptQueue.append(prompt)
                }
                return .none

            case .trustPrompt(.presented(.trustConfirmed)):
                state.trustPrompt?.prompt.resolve(with: .trustPermanently)
                state.trustPrompt = nil
                self.presentNextTrustPromptIfNeeded(state: &state)
                return .none

            case .trustPrompt(.presented(.cancelled)):
                state.trustPrompt?.prompt.resolve(with: .deny)
                state.trustPrompt = nil
                self.presentNextTrustPromptIfNeeded(state: &state)
                return .none

            case .trustPrompt(.dismiss):
                // Treat dismiss as deny, otherwise the URLSession challenge may hang forever.
                state.trustPrompt?.prompt.resolve(with: .deny)
                state.trustPrompt = nil
                self.presentNextTrustPromptIfNeeded(state: &state)
                return .none

            case .startupTimerElapsed:
                #if os(iOS)
                    state.startup.hasPresentedOnce = true
                    state.startup.minDurationElapsed = true
                    state.startup.isTimerScheduled = false
                #endif
                return .none

            case .openTorrentFile(let url):
                logger.info("Opening torrent file", metadata: ["url": url.absoluteString])
                guard url.isFileURL else {
                    logger.warning("Not a file URL", metadata: ["url": url.absoluteString])
                    return .none
                }
                guard url.pathExtension.lowercased() == "torrent" else {
                    logger.warning(
                        "Not a .torrent file", metadata: ["extension": url.pathExtension])
                    return .none
                }

                if let targetServer = preferredServer(in: state) {
                    return openTorrentFile(url, in: targetServer, state: &state)
                }

                state.pendingTorrentFileURL = url
                state.path = StackState()
                if state.serverList.isLoading == false {
                    return .send(.serverList(.task))
                }
                return .none

            case .serverList(.delegate(.addServerRequested)):
                state.path.append(.serverForm(ServerFormReducer.State(mode: .add)))
                return .none

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

            case .path(
                .element(id: _, action: .serverDetail(.delegate(.serverUpdated(let server))))):
                state.serverList.servers[id: server.id] = server
                return .none

            case .path(
                .element(id: let id, action: .serverDetail(.delegate(.serverDeleted(let serverID))))
            ):
                state.path[id: id] = nil
                state.serverList.servers.remove(id: serverID)
                return .none

            case .path(.element(id: _, action: .serverDetail(.delegate(.torrentSelected)))):
                return .none

            case .path(
                .element(
                    id: let detailID,
                    action: .serverDetail(.connectionResponse(.success(let response))))):
                guard case .serverDetail(let detailState) = state.path[id: detailID] else {
                    return .none
                }
                let serverID = detailState.server.id
                return .send(
                    .serverList(
                        .connectionProbeResponse(
                            serverID,
                            .success(.init(handshake: response.handshake))
                        )
                    )
                )

            case .path(
                .element(
                    id: let detailID,
                    action: .serverDetail(.connectionResponse(.failure(let error))))):
                guard case .serverDetail(let detailState) = state.path[id: detailID] else {
                    return .none
                }
                let serverID = detailState.server.id
                return .send(.serverList(.connectionProbeResponse(serverID, .failure(error))))

            case .path(
                .element(
                    id: let detailID,
                    action: .serverDetail(.torrentList(.storageUpdated(let summary))))):
                guard case .serverDetail(let detailState) = state.path[id: detailID], let summary
                else {
                    return .none
                }
                let serverID = detailState.server.id
                return .send(.serverList(.storageResponse(serverID, .success(summary))))

            case .path(
                .element(id: _, action: .serverDetail(.torrentList(.torrentsResponse(let result))))):
                #if os(iOS)
                    if let completion = state.backgroundFetchCompletion {
                        switch result {
                        case .success:
                            completion.run(.newData)
                        case .failure:
                            completion.run(.failed)
                        }
                        state.backgroundFetchCompletion = nil
                    }
                #endif
                return .none

            case .path(.element(id: _, action: .serverForm(.delegate(.didCreate(let server))))):
                state.serverList.servers.append(server)
                state.path.removeLast()
                return .merge(
                    .send(.serverList(.delegate(.serverCreated(server)))),
                    .send(.serverList(.connectionProbeRequested(server.id)))
                )

            case .path(.element(id: _, action: .serverForm(.delegate(.cancelled)))):
                state.path.removeLast()
                return .none

            case .path:
                return .none

            #if os(iOS)
                case .backgroundFetch(let completion):
                    guard let lastID = state.path.ids.last else {
                        completion.run(.noData)
                        return .none
                    }
                    state.backgroundFetchCompletion = completion
                    return .send(
                        .path(
                            .element(
                                id: lastID, action: .serverDetail(.torrentList(.refreshRequested))))
                    )
            #endif
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$trustPrompt, action: \.trustPrompt) {
            ServerTrustPromptReducer()
        }

        Scope(state: \.serverList, action: \.serverList) {
            ServerListReducer()
        }
    }

    @Reducer
    enum Path {
        case serverDetail(ServerDetailReducer)
        case serverForm(ServerFormReducer)
    }

    private func presentNextTrustPromptIfNeeded(state: inout State) {
        guard state.trustPrompt == nil else { return }
        guard state.trustPromptQueue.isEmpty == false else { return }
        state.trustPrompt = .init(prompt: state.trustPromptQueue.removeFirst())
    }

    private func preferredServer(in state: State) -> ServerConfig? {
        let lastServer = state.path.ids.last.flatMap { id -> ServerConfig? in
            guard case .serverDetail(let detail) = state.path[id: id] else { return nil }
            return detail.server
        }
        if let lastServer { return lastServer }
        return preferredServer(from: Array(state.serverList.servers), in: state)
    }

    private func preferredServer(from servers: [ServerConfig], in state: State) -> ServerConfig? {
        let lastServer = state.path.ids.last.flatMap { id -> ServerConfig? in
            guard case .serverDetail(let detail) = state.path[id: id] else { return nil }
            return detail.server
        }
        if let lastServer { return lastServer }
        return servers.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    private func openServerDetail(
        _ server: ServerConfig,
        state: inout State
    ) -> Effect<Action> {
        let activeServer = state.path.ids.last.flatMap { id -> ServerConfig? in
            guard case .serverDetail(let detail) = state.path[id: id] else { return nil }
            return detail.server
        }
        if activeServer?.id == server.id {
            return .none
        }
        state.path.append(.serverDetail(ServerDetailReducer.State(server: server)))
        return .none
    }

    private func openTorrentFile(
        _ url: URL,
        in server: ServerConfig,
        state: inout State
    ) -> Effect<Action> {
        let activeServer = state.path.ids.last.flatMap { id -> ServerConfig? in
            guard case .serverDetail(let detail) = state.path[id: id] else { return nil }
            return detail.server
        }
        if activeServer?.id == server.id {
            guard let lastID = state.path.ids.last else { return .none }
            return .send(
                .path(.element(id: lastID, action: .serverDetail(.fileImportResult(.success(url)))))
            )
        }

        state.path.append(.serverDetail(ServerDetailReducer.State(server: server)))
        guard let targetID = state.path.ids.last else { return .none }
        return .send(
            .path(.element(id: targetID, action: .serverDetail(.fileImportResult(.success(url))))))
    }
}

extension AppReducer.Path.State: Equatable {}
extension AppReducer.Path.Action: Equatable {}

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

#if os(iOS)
    struct BackgroundFetchCompletion: Equatable {
        let id = UUID()
        let run: (UIBackgroundFetchResult) -> Void
        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }
#endif
