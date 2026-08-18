import ComposableArchitecture
import Foundation

@Reducer
struct ServerConnectionReducer {
    struct Connected: Equatable {
        var environment: ServerConnectionEnvironment
        var handshake: TransmissionHandshakeResult
    }

    struct Disconnected: Equatable {
        var message: String
        var attempt: Int
    }

    enum Phase: Equatable {
        case idle
        case connecting
        case connected(Connected)
        case disconnected(Disconnected)
    }

    enum AlertAction: Equatable {
        case confirmHTTPConnection
        case cancelHTTPConnection
    }

    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        var phase: Phase = .idle
        var failedConnectionAttempts = 0
        @Presents var alert: AlertState<AlertAction>?

        init(server: ServerConfig) {
            self.server = server
        }
    }

    @CasePathable
    enum Action: Equatable {
        case task
        case retryRequested
        case manualRetryRequested
        case connectionResponse(TaskResult<ConnectionResponse>)
        case showHTTPWarning
        case alert(PresentationAction<AlertAction>)
    }

    struct ConnectionResponse: Equatable {
        var environment: ServerConnectionEnvironment
        var handshake: TransmissionHandshakeResult
    }

    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore
    @Dependency(\.serverConnectionEnvironmentFactory) var serverConnectionEnvironmentFactory
    @Dependency(\.appClock) var appClock

    enum CancellationID: Hashable {
        case connection
        case automaticRetry
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                guard case .idle = state.phase else { return .none }
                state.phase = .connecting
                return startConnection(server: state.server)

            case .retryRequested:
                guard case .disconnected(let disconnected) = state.phase,
                    disconnected.attempt < 3
                else { return .none }
                state.failedConnectionAttempts = max(
                    state.failedConnectionAttempts,
                    disconnected.attempt
                )
                state.phase = .connecting
                return startConnection(server: state.server)

            case .manualRetryRequested:
                state.failedConnectionAttempts = 0
                state.phase = .connecting
                return .merge(
                    .cancel(id: CancellationID.automaticRetry),
                    startConnection(server: state.server)
                )

            case .connectionResponse(.success(let response)):
                guard case .connecting = state.phase else { return .none }
                state.failedConnectionAttempts = 0
                state.phase = .connected(
                    .init(environment: response.environment, handshake: response.handshake)
                )
                return .cancel(id: CancellationID.automaticRetry)

            case .connectionResponse(.failure(let error)):
                guard case .connecting = state.phase else { return .none }
                let previousAttempt: Int
                if case .disconnected(let previous) = state.phase {
                    previousAttempt = previous.attempt
                } else {
                    previousAttempt = 0
                }
                let attempt = max(state.failedConnectionAttempts, previousAttempt) + 1
                state.failedConnectionAttempts = attempt
                state.phase = .disconnected(
                    .init(message: error.userFacingMessage, attempt: attempt)
                )
                return scheduleAutomaticRetry(after: attempt)

            case .showHTTPWarning:
                state.alert = AlertFactory.httpConnectionWarning(
                    confirmAction: .confirmHTTPConnection,
                    cancelAction: .cancelHTTPConnection
                )
                return .none

            case .alert(.presented(.confirmHTTPConnection)):
                state.alert = nil
                let fingerprint = state.server.httpWarningFingerprint
                return .run { send in
                    await httpWarningPreferencesStore.setSuppressed(fingerprint, true)
                    await send(.manualRetryRequested)
                }

            case .alert(.presented(.cancelHTTPConnection)):
                state.alert = nil
                state.phase = .idle
                return .none

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func startConnection(server: ServerConfig) -> Effect<Action> {
        .run { send in
            let isSuppressed = await httpWarningPreferencesStore.isSuppressed(
                server.httpWarningFingerprint
            )
            guard !server.usesInsecureTransport || isSuppressed else {
                await send(.showHTTPWarning)
                return
            }

            await send(
                .connectionResponse(
                    TaskResult {
                        let environment = try await serverConnectionEnvironmentFactory.make(server)
                        let handshake = try await environment.withDependencies {
                            @Dependency(\.transmissionClient) var client
                            return try await client.performHandshake()
                        }
                        return ConnectionResponse(
                            environment: environment,
                            handshake: handshake
                        )
                    }
                )
            )
        }
        .cancellable(id: CancellationID.connection, cancelInFlight: true)
    }

    private func scheduleAutomaticRetry(after attempt: Int) -> Effect<Action> {
        guard attempt < 3 else { return .cancel(id: CancellationID.automaticRetry) }
        let delay = BackoffStrategy.delay(for: attempt)
        return .run { send in
            do {
                try await appClock.clock().sleep(for: delay)
                await send(.retryRequested)
            } catch is CancellationError {
                return
            }
        }
        .cancellable(id: CancellationID.automaticRetry, cancelInFlight: true)
    }
}
