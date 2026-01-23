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
        @Presents var onboarding: OnboardingReducer.State?
        @Presents var editor: ServerEditorReducer.State?
        var hasPresentedInitialOnboarding: Bool = false
        var shouldLoadServersFromRepository: Bool = true
        var hasAutoSelectedSingleServer: Bool = false
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
        case onboarding(PresentationAction<OnboardingReducer.Action>)
        case editor(PresentationAction<ServerEditorReducer.Action>)
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

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                if state.shouldLoadServersFromRepository == false {
                    state.shouldLoadServersFromRepository = true
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
                state.onboarding = OnboardingReducer.State()
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
                state.editor = ServerEditorReducer.State(server: server)
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

            case .onboarding(.presented(.delegate(.didCreate(let server)))):
                state.servers.append(server)
                state.onboarding = nil
                return .merge(
                    .send(.delegate(.serverCreated(server))),
                    .send(.connectionProbeRequested(server.id)),
                    .run { send in
                        await send(
                            .serverRepositoryResponse(
                                TaskResult {
                                    try await serverConfigRepository.upsert(server)
                                }
                            )
                        )
                    }
                )

            case .onboarding(.presented(.delegate(.cancelled))):
                state.onboarding = nil
                return .none

            case .onboarding:
                return .none

            case .editor(.presented(.delegate(.didUpdate(let server)))):
                if let index = state.servers.index(id: server.id) {
                    state.servers[index] = server
                }
                state.editor = nil
                return .send(.connectionProbeRequested(server.id))

            case .editor(.presented(.delegate(.cancelled))):
                state.editor = nil
                return .none

            case .editor(.dismiss):
                state.editor = nil
                return .none

            case .editor:
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
                            state.onboarding = OnboardingReducer.State()
                            state.hasPresentedInitialOnboarding = true
                        }
                    #endif
                }
                let shouldAutoSelect =
                    servers.count == 1
                    && state.hasAutoSelectedSingleServer == false
                    && state.onboarding == nil
                    && state.editor == nil
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
                        let session = try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.sessionRepository) var sessionRepository:
                                SessionRepository
                            return try await sessionRepository.fetchState()
                        }
                        let torrents = try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.torrentRepository) var torrentRepository:
                                TorrentRepository
                            return try await torrentRepository.fetchList()
                        }
                        let snapshot = try? await environment.snapshot.load()
                        let summary = makeStorageSummary(
                            torrents: torrents,
                            session: session,
                            updatedAt: snapshot?.latestUpdatedAt
                        )
                        await send(.storageResponse(id, .success(summary)))
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
        .ifLet(\.$onboarding, action: \.onboarding) {
            OnboardingReducer()
        }
        .ifLet(\.$editor, action: \.editor) {
            ServerEditorReducer()
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

    private func resetTrust(for server: ServerConfig) -> Effect<Action> {
        .run { send in
            let identity = TransmissionServerTrustIdentity(
                host: server.connection.host,
                port: server.connection.port,
                isSecure: server.isSecure
            )
            do {
                try transmissionTrustStoreClient.deleteFingerprint(identity)
            } catch {
                // If trust reset fails, surface an alert and continue.
                await send(
                    .serverRepositoryResponse(
                        .failure(error)
                    )
                )
            }
        }
    }

    private func describe(_ error: Error) -> String {
        if let probeError = error as? ServerConnectionProbe.ProbeError {
            return probeError.displayMessage
        }
        return (error as NSError).localizedDescription
    }

    private func makeStorageSummary(
        torrents: [Torrent],
        session: SessionState,
        updatedAt: Date?
    ) -> StorageSummary {
        let usedBytes = torrents.reduce(Int64(0)) { total, torrent in
            total + Int64(torrent.summary.progress.totalSize)
        }
        let totalBytes = usedBytes + session.storage.freeBytes
        return StorageSummary(
            totalBytes: totalBytes,
            freeBytes: session.storage.freeBytes,
            updatedAt: updatedAt
        )
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
