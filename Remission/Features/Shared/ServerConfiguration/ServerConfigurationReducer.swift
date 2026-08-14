import ComposableArchitecture
import Foundation

@Reducer
struct ServerConfigurationReducer {
    @ObservableState
    struct State: Equatable, Sendable {
        var form: ServerConnectionFormState = .init()
        var validationError: String?
        var connectionStatus: ServerConnectionStatus = .idle
        var verifiedSubmission: ServerSubmissionContext?
        var pendingHTTPSubmission: ServerSubmissionContext?
        @Presents var alert: AlertState<AlertAction>?

        var isCheckButtonDisabled: Bool {
            connectionStatus == .testing
        }
    }

    enum Action: BindableAction, Equatable, Sendable {
        case binding(BindingAction<State>)
        case checkConnectionButtonTapped
        case connectionTestFinished(ServerConnectionTestResult)
        case alert(PresentationAction<AlertAction>)

        case uiTestBypassConnection  // Для UI тестов

        case showHTTPWarning(ServerSubmissionContext)
        case startConnectionProbeAfterCheck(ServerSubmissionContext)

        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case connectionVerified(ServerSubmissionContext)
        case formChanged
    }

    enum AlertAction: Equatable {
        case confirmHTTPConnection
        case cancelHTTPConnection
    }

    @Dependency(\.serverConnectionProbe) var serverConnectionProbe
    @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.dateProvider) var dateProvider
    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore

    private enum CancellationID: Hashable {
        case connectionProbe
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(let action):
                state.validationError = nil

                if action.keyPath == \State.form.name {
                    state.form.name = state.form.name.filtered(allowed: .serverNameCharacters)
                } else if action.keyPath == \State.form.host {
                    state.form.host = state.form.host.replacingOccurrences(of: " ", with: "")
                        .filteredASCII(allowed: .hostCharacters)
                } else if action.keyPath == \State.form.port {
                    let digits = state.form.port.replacingOccurrences(of: " ", with: "").filtered(
                        allowed: .decimalDigits)
                    state.form.port = String(digits.prefix(5))
                } else if action.keyPath == \State.form.path {
                    state.form.path = state.form.path.replacingOccurrences(of: " ", with: "")
                        .filteredASCII(allowed: .pathCharacters)
                } else if action.keyPath == \State.form.username {
                    state.form.username = state.form.username.replacingOccurrences(
                        of: " ", with: ""
                    )
                    .filtered(allowed: .usernameCharacters)
                } else if action.keyPath == \State.form.password {
                    state.form.password = state.form.password.filtered(allowed: .passwordCharacters)
                }

                let resetEffect = self.resetConnectionState(state: &state)
                return .merge(resetEffect, .send(.delegate(.formChanged)))

            case .checkConnectionButtonTapped:
                guard state.connectionStatus != .testing else { return .none }
                guard let context = self.prepareSubmission(state: &state) else { return .none }
                guard context.server.usesInsecureTransport else {
                    return self.startConnectionProbe(state: &state, context: context)
                }
                // Check httpWarningPreferencesStore asynchronously, but set pending state first
                state.pendingHTTPSubmission = context
                state.alert = AlertFactory.httpConnectionWarning(
                    confirmAction: .confirmHTTPConnection,
                    cancelAction: .cancelHTTPConnection
                )
                return .run { [context] send in
                    let isSuppressed = await httpWarningPreferencesStore.isSuppressed(
                        context.server.httpWarningFingerprint)
                    if isSuppressed {
                        await send(.startConnectionProbeAfterCheck(context))
                    } else {
                        // Already showed warning, wait for user confirmation
                    }
                }

            case .alert(.presented(.confirmHTTPConnection)):
                guard let context = state.pendingHTTPSubmission else { return .none }
                state.pendingHTTPSubmission = nil
                state.alert = nil
                state.connectionStatus = .testing
                state.verifiedSubmission = context
                return .run { [context] send in
                    await httpWarningPreferencesStore.setSuppressed(
                        context.server.httpWarningFingerprint, true)
                    await send(.startConnectionProbeAfterCheck(context))
                }

            case .alert(.presented(.cancelHTTPConnection)), .alert(.dismiss):
                state.pendingHTTPSubmission = nil
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .startConnectionProbeAfterCheck(let context):
                return self.startConnectionProbe(state: &state, context: context)

            case .connectionTestFinished(.success(let handshake)):
                state.connectionStatus = .success(handshake)
                if let verified = state.verifiedSubmission {
                    return .merge(
                        .cancel(id: CancellationID.connectionProbe),
                        .send(.delegate(.connectionVerified(verified)))
                    )
                }
                return .merge(
                    .cancel(id: CancellationID.connectionProbe)
                )

            case .connectionTestFinished(.failure(let message)):
                state.connectionStatus = .failed(message)
                state.verifiedSubmission = nil
                return .merge(
                    .cancel(id: CancellationID.connectionProbe)
                )

            case .uiTestBypassConnection:
                guard let context = self.prepareSubmission(state: &state) else { return .none }
                state.connectionStatus = .success(.uiTestPlaceholder)
                state.verifiedSubmission = context
                return .send(.delegate(.connectionVerified(context)))

            case .delegate:
                return .none

            case .showHTTPWarning:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func resetConnectionState(state: inout State) -> Effect<Action> {
        if state.connectionStatus != .idle || state.verifiedSubmission != nil {
            state.connectionStatus = .idle
            state.verifiedSubmission = nil
        }
        state.pendingHTTPSubmission = nil
        return .merge(
            .cancel(id: CancellationID.connectionProbe)
        )
    }

    private func prepareSubmission(state: inout State) -> ServerSubmissionContext? {
        guard state.form.isFormValid, state.form.portValue != nil else {
            state.validationError = L10n.tr("onboarding.error.validation.hostPort")
            return nil
        }
        state.validationError = nil

        let server = state.form.makeServerConfig(
            id: uuidGenerator.generate(),
            createdAt: dateProvider.now()
        )
        let password = state.form.password.isEmpty ? nil : state.form.password

        return ServerSubmissionContext(server: server, password: password)
    }

    private func startConnectionProbe(
        state: inout State,
        context: ServerSubmissionContext
    ) -> Effect<Action> {
        state.connectionStatus = .testing
        state.verifiedSubmission = context
        return .run { [context] send in
            do {
                let result = try await serverConnectionProbe.run(
                    .init(server: context.server, password: context.password),
                    trustPromptCenter.makeHandler()
                )
                await send(.connectionTestFinished(.success(result.handshake)))
            } catch let probeError as ServerConnectionProbe.ProbeError {
                await send(.connectionTestFinished(.failure(probeError.displayMessage)))
            } catch {
                await send(
                    .connectionTestFinished(
                        .failure(error.userFacingMessage)))
            }
        }
        .cancellable(id: CancellationID.connectionProbe, cancelInFlight: true)
    }
}

extension ServerConfigurationReducer.State {
    var checkConnectionButtonTitle: String {
        switch connectionStatus {
        case .idle:
            return L10n.tr("onboarding.action.checkConnection")
        case .testing:
            return L10n.tr("onboarding.status.testing")
        case .success:
            return L10n.tr("onboarding.status.success")
        case .failed:
            return L10n.tr("onboarding.status.error")
        }
    }

    enum ConnectionButtonVariant: Sendable, Equatable {
        case neutral
        case success
        case error
        case accent
    }

    var checkConnectionButtonVariant: ConnectionButtonVariant {
        switch connectionStatus {
        case .success:
            return .success
        case .failed:
            return .error
        case .idle, .testing:
            return .neutral
        }
    }
}

extension TransmissionHandshakeResult {
    static let uiTestPlaceholder: TransmissionHandshakeResult = .init(
        sessionID: "uitest-placeholder",
        rpcVersion: 22,
        minimumSupportedRpcVersion: 14,
        serverVersionDescription: "Transmission 4.0 (UI Tests)",
        isCompatible: true
    )
}
