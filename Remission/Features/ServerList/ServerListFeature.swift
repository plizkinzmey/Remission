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
            .merge(
                connectionReducer(state: &state, action: action),
                managementReducer(state: &state, action: action),
                storageReducer(state: &state, action: action)
            )
        }
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$deleteConfirmation, action: \.deleteConfirmation)
        .ifLet(\.$serverForm, action: \.serverForm) {
            ServerFormReducer()
        }
    }

    func describe(_ error: Error) -> String {
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

enum ConnectionCancellationID: Hashable {
    case connectionProbe(UUID)
    case storage(UUID)
}
