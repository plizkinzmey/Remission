import ComposableArchitecture
import Foundation

@Reducer
struct ServerListReducer {
    @ObservableState
    struct State: Equatable {
        var servers: IdentifiedArrayOf<ServerConfig> = []
        var isLoading: Bool = false
        @Presents var alert: AlertState<Alert>?
        @Presents var onboarding: OnboardingReducer.State?
        var hasPresentedInitialOnboarding: Bool = false
        var shouldLoadServersFromRepository: Bool = true
    }

    enum Action: Equatable {
        case task
        case addButtonTapped
        case serverTapped(UUID)
        case remove(IndexSet)
        case alert(PresentationAction<Alert>)
        case onboarding(PresentationAction<OnboardingReducer.Action>)
        case serverRepositoryResponse(TaskResult<[ServerConfig]>)
        case delegate(Delegate)
    }

    enum Alert: Equatable {
        case comingSoon
    }

    enum Delegate: Equatable {
        case serverSelected(ServerConfig)
        case serverCreated(ServerConfig)
    }

    @Dependency(\.onboardingProgressRepository) var onboardingProgressRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository

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

            case .remove(let indexSet):
                let ids: [UUID] = indexSet.compactMap { index in
                    guard state.servers.indices.contains(index) else { return nil }
                    return state.servers[index].id
                }
                state.servers.remove(atOffsets: indexSet)
                guard ids.isEmpty == false else { return .none }
                return .run { send in
                    await send(
                        .serverRepositoryResponse(
                            TaskResult {
                                try await serverConfigRepository.delete(ids)
                            }
                        )
                    )
                }

            case .alert:
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
                    TextState("Не удалось обновить список серверов")
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState("Понятно")
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
        .ifLet(\.$onboarding, action: \.onboarding) {
            OnboardingReducer()
        }
    }
}
