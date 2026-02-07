import ComposableArchitecture
import Foundation

@Reducer
struct ServerConfigurationReducer {
    @ObservableState
    struct State: Equatable {
        var form: ServerConnectionFormState = .init()
        var validationError: String?
        var connectionStatus: ServerConnectionStatus = .idle
        var verifiedSubmission: ServerSubmissionContext?

        var isCheckButtonDisabled: Bool {
            connectionStatus == .testing
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case checkConnectionButtonTapped
        case connectionTestFinished(ServerConnectionTestResult)

        case uiTestBypassConnection  // Для UI тестов

        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case connectionVerified(ServerSubmissionContext)
        case formChanged
    }

    @Dependency(\.serverConnectionProbe) var serverConnectionProbe
    @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.dateProvider) var dateProvider

    private enum CancellationID: Hashable {
        case connectionProbe
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            self.core(state: &state, action: action)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding(let action):
            state.validationError = nil

            if action.keyPath == \State.form.name {
                state.form.name = state.form.name.filtered(allowed: .alphanumerics)
            } else if action.keyPath == \State.form.host {
                state.form.host = state.form.host.filteredASCII(allowed: .hostCharacters)
            } else if action.keyPath == \State.form.port {
                state.form.port = state.form.port.filtered(allowed: .decimalDigits)
            } else if action.keyPath == \State.form.path {
                state.form.path = state.form.path.filteredASCII(allowed: .pathCharacters)
            } else if action.keyPath == \State.form.username {
                state.form.username = state.form.username.filtered(allowed: .alphanumerics)
            } else if action.keyPath == \State.form.password {
                state.form.password = state.form.password.filteredASCII(allowed: .alphanumerics)
            }

            let resetEffect = self.resetConnectionState(state: &state)
            return .merge(resetEffect, .send(.delegate(.formChanged)))

        case .checkConnectionButtonTapped:
            guard state.connectionStatus != .testing else { return .none }
            guard let context = self.prepareSubmission(state: &state) else { return .none }
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
        }
    }

    private func resetConnectionState(state: inout State) -> Effect<Action> {
        if state.connectionStatus != .idle || state.verifiedSubmission != nil {
            state.connectionStatus = .idle
            state.verifiedSubmission = nil
        }
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

        let context = ServerSubmissionContext(server: server, password: password)
        state.verifiedSubmission = context
        return context
    }

    private func startConnectionProbe(
        state: inout State,
        context: ServerSubmissionContext
    ) -> Effect<Action> {
        state.connectionStatus = .testing
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

    var checkConnectionButtonVariant: AppFooterButtonStyle.Variant {
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
