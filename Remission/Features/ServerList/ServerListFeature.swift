import ComposableArchitecture
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
        var hasPresentedInitialOnboarding: Bool = false
        var shouldLoadServersFromRepository: Bool = true
        var pendingDeletion: ServerConfig?
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
        case serverRepositoryResponse(TaskResult<[ServerConfig]>)
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
        case serverEditRequested(ServerConfig)
    }

    @Dependency(\.onboardingProgressRepository) var onboardingProgressRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore
    @Dependency(\.transmissionTrustStoreClient) var transmissionTrustStoreClient
    @Dependency(\.serverConnectionProbe) var serverConnectionProbe

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
                return .send(.delegate(.serverEditRequested(server)))

            case .deleteButtonTapped(let id):
                guard let server = state.servers[id: id] else { return .none }
                state.pendingDeletion = server
                state.deleteConfirmation = makeDeleteConfirmation(for: server)
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

            case .serverRepositoryResponse(.success(let servers)):
                state.isLoading = false
                state.servers = IdentifiedArrayOf(uniqueElements: servers)
                if servers.isEmpty {
                    let shouldShowOnboarding =
                        state.hasPresentedInitialOnboarding == false
                        && onboardingProgressRepository.hasCompletedOnboarding() == false
                    if shouldShowOnboarding {
                        state.onboarding = OnboardingReducer.State()
                        state.hasPresentedInitialOnboarding = true
                    }
                }
                return .none

            case .serverRepositoryResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState(L10n.tr("serverList.alert.refreshFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(error.localizedDescription)
                }
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
    }

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

    private func makeDeleteConfirmation(for server: ServerConfig) -> ConfirmationDialogState<
        DeleteConfirmationAction
    > {
        ConfirmationDialogState {
            TextState(
                String(
                    format: L10n.tr("serverList.alert.delete.title"),
                    server.name
                )
            )
        } actions: {
            ButtonState(role: .destructive, action: .confirm) {
                TextState(L10n.tr("serverList.alert.delete.confirm"))
            }
            ButtonState(role: .cancel, action: .cancel) {
                TextState(L10n.tr("serverList.alert.delete.cancel"))
            }
        } message: {
            TextState(L10n.tr("serverList.alert.delete.message"))
        }
    }
}
