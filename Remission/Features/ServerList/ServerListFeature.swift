import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct ServerListReducer {
    @ObservableState
    struct State: Equatable {
        var servers: IdentifiedArrayOf<ServerConfig> = []
        var isLoading: Bool = false
        @Presents var alert: AlertState<Alert>?
        @Presents var deleteConfirmation: ConfirmationDialogState<DeleteConfirmationAction>?
        @Presents var serverForm: ServerFormReducer.State?
        var hasPresentedInitialOnboarding: Bool = false
        var hasAutoSelectedSingleServer: Bool = false
        var isPreloaded: Bool = false
        var pendingDeletion: ServerConfig?
        var connectionStatuses: [UUID: ConnectionStatus] = [:]
    }

    enum Action: Equatable {
        case task
        case addButtonTapped
        case serverTapped(UUID)
        case editButtonTapped(UUID)
        case deleteButtonTapped(UUID)
        case deleteConfirmation(PresentationAction<DeleteConfirmationAction>)
        case alert(PresentationAction<Alert>)
        case serverForm(PresentationAction<ServerFormReducer.Action>)
        case serverRepositoryResponse(TaskResult<[ServerConfig]>)
        case connectionProbeRequested(UUID)
        case connectionProbeResponse(UUID, TaskResult<ServerConnectionProbe.Result>)
        case storageRequested(UUID)
        case storageResponse(UUID, TaskResult<StorageSummary>)
        case delegate(Delegate)
    }

    enum Alert: Equatable {
        case comingSoon
        case dismiss
    }

    enum DeleteConfirmationAction: Equatable {
        case confirm
        case cancel
    }

    enum Delegate: Equatable {
        case serverSelected(ServerConfig)
        case serverCreated(ServerConfig)
    }

    @Dependency(\.onboardingProgressRepository) var onboardingProgressRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore
    @Dependency(\.transmissionTrustStoreClient) var transmissionTrustStoreClient
    @Dependency(\.serverConnectionProbe) var serverConnectionProbe
    @Dependency(\.serverConnectionEnvironmentFactory) var serverConnectionEnvironmentFactory

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                if state.isPreloaded {
                    state.isLoading = false
                    return .none
                }
                guard state.isLoading == false else { return .none }
                state.isLoading = true
                return .run { send in
                    await send(
                        .serverRepositoryResponse(
                            TaskResult {
                                try await serverConfigRepository.load()
                            }
                        )
                    )
                }

            case .addButtonTapped:
                state.hasPresentedInitialOnboarding = true
                state.serverForm = ServerFormReducer.State(mode: .add)
                return .none

            case .serverTapped(let id):
                guard let server = state.servers[id: id] else {
                    return .none
                }
                return .send(.delegate(.serverSelected(server)))

            case .editButtonTapped(let id):
                guard let server = state.servers[id: id] else {
                    return .none
                }
                state.serverForm = ServerFormReducer.State(mode: .edit(server))
                return .none

            case .deleteButtonTapped(let id):
                guard let server = state.servers[id: id] else { return .none }
                state.pendingDeletion = server
                state.deleteConfirmation = AlertFactory.confirmationDialog(
                    title: String(format: L10n.tr("serverList.alert.delete.title"), server.name),
                    message: L10n.tr("serverList.alert.delete.message"),
                    confirmAction: .confirm,
                    cancelAction: .cancel
                )
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .deleteConfirmation(.presented(.confirm)):
                guard let server = state.pendingDeletion else {
                    state.deleteConfirmation = nil
                    return .none
                }
                state.pendingDeletion = nil
                state.deleteConfirmation = nil
                return deleteServer(server)

            case .deleteConfirmation(.presented(.cancel)):
                state.pendingDeletion = nil
                state.deleteConfirmation = nil
                return .none

            case .deleteConfirmation:
                return .none

            case .serverForm(.presented(.delegate(.didCreate(let server)))):
                state.servers.append(server)
                state.serverForm = nil
                return .merge(
                    .send(.delegate(.serverCreated(server))),
                    .send(.connectionProbeRequested(server.id))
                )

            case .serverForm(.presented(.delegate(.didUpdate(let server)))):
                state.servers[id: server.id] = server
                state.serverForm = nil
                return .send(.connectionProbeRequested(server.id))

            case .serverForm(.presented(.delegate(.cancelled))):
                state.serverForm = nil
                return .none

            case .serverForm(.dismiss):
                state.serverForm = nil
                return .none

            case .serverForm:
                return .none

            case .serverRepositoryResponse(.success(let servers)):
                state.isLoading = false
                state.servers = IdentifiedArrayOf(uniqueElements: servers)
                let identifiers = Set(servers.map(\.id))
                state.connectionStatuses = Dictionary(
                    uniqueKeysWithValues: state.connectionStatuses.filter {
                        identifiers.contains($0.key)
                    }
                )
                if servers.isEmpty {
                    #if os(macOS)
                        let shouldShowOnboarding =
                            state.hasPresentedInitialOnboarding == false
                            && onboardingProgressRepository.hasCompletedOnboarding() == false
                        if shouldShowOnboarding {
                            state.serverForm = ServerFormReducer.State(mode: .add)
                            state.hasPresentedInitialOnboarding = true
                        }
                    #endif
                }
                let shouldAutoSelect =
                    servers.count == 1
                    && state.hasAutoSelectedSingleServer == false
                    && state.serverForm == nil
                if shouldAutoSelect {
                    state.hasAutoSelectedSingleServer = true
                }
                return .run { [servers, shouldAutoSelect] send in
                    for server in servers {
                        await send(.connectionProbeRequested(server.id))
                    }
                    if shouldAutoSelect, let server = servers.first {
                        await send(.delegate(.serverSelected(server)))
                    }
                }

            case .serverRepositoryResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertFactory.simpleAlert(
                    title: L10n.tr("serverList.alert.refreshFailed.title"),
                    message: error.localizedDescription,
                    action: .dismiss
                )
                return .none

            case .connectionProbeRequested(let id):
                guard let server = state.servers[id: id] else { return .none }
                if state.connectionStatuses[id]?.isProbing == true {
                    return .none
                }
                state.connectionStatuses[id] = .init(phase: .probing)
                return .run { [server] send in
                    do {
                        let password: String?
                        if let credentialsKey = server.credentialsKey {
                            guard
                                let credentials = try await credentialsRepository.load(
                                    key: credentialsKey
                                )
                            else {
                                throw ServerConnectionEnvironmentFactoryError.missingCredentials
                            }
                            password = credentials.password
                        } else {
                            password = nil
                        }
                        let result = try await serverConnectionProbe.run(
                            .init(server: server, password: password),
                            nil
                        )
                        await send(.connectionProbeResponse(server.id, .success(result)))
                    } catch {
                        await send(
                            .connectionProbeResponse(
                                server.id,
                                .failure(error)
                            )
                        )
                    }
                }
                .cancellable(id: ConnectionCancellationID.connectionProbe(id), cancelInFlight: true)

            case .connectionProbeResponse(let id, .success(let result)):
                state.connectionStatuses[id] = .init(phase: .connected(result.handshake))
                return .send(.storageRequested(id))

            case .connectionProbeResponse(let id, .failure(let error)):
                state.connectionStatuses[id] = .init(phase: .failed(describe(error)))
                return .none

            case .storageRequested(let id):
                guard let server = state.servers[id: id] else { return .none }
                if state.connectionStatuses[id]?.isLoadingStorage == true {
                    return .none
                }
                if state.connectionStatuses[id]?.storageSummary != nil {
                    return .none
                }
                state.connectionStatuses[id]?.isLoadingStorage = true
                return .run { [server] send in
                    do {
                        let environment = try await serverConnectionEnvironmentFactory(server)
                        let session = try await environment.withDependencies {
                            @Dependency(\.sessionRepository) var sessionRepository:
                                SessionRepository
                            return try await sessionRepository.fetchState()
                        }
                        let torrents = try await environment.withDependencies {
                            @Dependency(\.torrentRepository) var torrentRepository:
                                TorrentRepository
                            return try await torrentRepository.fetchList()
                        }
                        let snapshot = try? await environment.snapshot.load()
                        if let summary = StorageSummary.calculate(
                            torrents: torrents,
                            session: session,
                            updatedAt: snapshot?.latestUpdatedAt
                        ) {
                            await send(.storageResponse(id, .success(summary)))
                        }
                    } catch {
                        await send(.storageResponse(id, .failure(error)))
                    }
                }
                .cancellable(id: ConnectionCancellationID.storage(id), cancelInFlight: true)

            case .storageResponse(let id, .success(let summary)):
                state.connectionStatuses[id]?.storageSummary = summary
                state.connectionStatuses[id]?.isLoadingStorage = false
                return .none

            case .storageResponse(let id, .failure):
                state.connectionStatuses[id]?.isLoadingStorage = false
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$deleteConfirmation, action: \.deleteConfirmation)
        .ifLet(\.$serverForm, action: \.serverForm) {
            ServerFormReducer()
        }
    }
}

extension ServerListReducer {
    private func deleteServer(_ server: ServerConfig) -> Effect<Action> {
        .run { send in
            do {
                if let key = server.credentialsKey {
                    try await credentialsRepository.delete(key: key)
                }
                httpWarningPreferencesStore.reset(server.httpWarningFingerprint)
                let identity = TransmissionServerTrustIdentity(
                    host: server.connection.host,
                    port: server.connection.port,
                    isSecure: server.isSecure
                )
                try transmissionTrustStoreClient.deleteFingerprint(identity)
                let updated = try await serverConfigRepository.delete([server.id])
                await send(.serverRepositoryResponse(.success(updated)))
            } catch {
                await send(.serverRepositoryResponse(.failure(error)))
            }
        }
    }

    private func describe(_ error: Error) -> String {
        error.userFacingMessage
    }
}

extension ServerListReducer {
    enum ConnectionStatusPhase: Equatable {
        case idle
        case probing
        case connected(TransmissionHandshakeResult)
        case failed(String)
    }

    struct ConnectionStatus: Equatable {
        var phase: ConnectionStatusPhase = .idle
        var storageSummary: StorageSummary?
        var isLoadingStorage: Bool = false

        var isProbing: Bool {
            if case .probing = phase { return true }
            return false
        }
    }
}

private enum ConnectionCancellationID: Hashable {
    case connectionProbe(UUID)
    case storage(UUID)
}