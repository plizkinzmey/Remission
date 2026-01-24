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

        @Presents var trustPrompt: ServerTrustPromptReducer.State?

        var isCheckButtonDisabled: Bool {
            connectionStatus == .testing
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case checkConnectionButtonTapped
        case connectionTestFinished(ServerConnectionTestResult)
        case trustPromptReceived(TransmissionTrustPrompt)
        case trustPrompt(PresentationAction<ServerTrustPromptReducer.Action>)

        case uiTestBypassConnection  // Для UI тестов

        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case connectionVerified(ServerSubmissionContext)
        case formChanged
    }

    @Dependency(\.serverConnectionProbe) var serverConnectionProbe
    @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter

    private enum CancellationID: Hashable {
        case connectionProbe
        case trustPrompts
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            self.core(state: &state, action: action)
        }
        .ifLet(\.$trustPrompt, action: \.trustPrompt) {
            ServerTrustPromptReducer()
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
                    .cancel(id: CancellationID.trustPrompts),
                    .send(.delegate(.connectionVerified(verified)))
                )
            }
            return .merge(
                .cancel(id: CancellationID.connectionProbe),
                .cancel(id: CancellationID.trustPrompts)
            )

        case .connectionTestFinished(.failure(let message)):
            state.connectionStatus = .failed(message)
            state.verifiedSubmission = nil
            return .merge(
                .cancel(id: CancellationID.connectionProbe),
                .cancel(id: CancellationID.trustPrompts)
            )

        case .trustPromptReceived(let prompt):
            state.trustPrompt = ServerTrustPromptReducer.State(prompt: prompt)
            return .none

        case .trustPrompt(.presented(.trustConfirmed)):
            state.trustPrompt?.prompt.resolve(with: .trustPermanently)
            state.trustPrompt = nil
            return .none

        case .trustPrompt(.presented(.cancelled)):
            state.trustPrompt?.prompt.resolve(with: .deny)
            state.trustPrompt = nil
            return .none

        case .trustPrompt(.dismiss):
            state.trustPrompt = nil
            return .none

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
            .cancel(id: CancellationID.connectionProbe),
            .cancel(id: CancellationID.trustPrompts)
        )
    }

    private func prepareSubmission(state: inout State) -> ServerSubmissionContext? {
        guard state.form.isFormValid, state.form.portValue != nil else {
            state.validationError = L10n.tr("onboarding.error.validation.hostPort")
            return nil
        }
        state.validationError = nil

        let server = state.form.makeServerConfig(id: UUID(), createdAt: Date())
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
        return .merge(
            .run { [context] send in
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
            .cancellable(id: CancellationID.connectionProbe, cancelInFlight: true),
            listenForTrustPrompts()
        )
    }

    private func listenForTrustPrompts() -> Effect<Action> {
        .run { send in
            for await prompt in trustPromptCenter.prompts {
                await send(.trustPromptReceived(prompt))
            }
        }
        .cancellable(id: CancellationID.trustPrompts, cancelInFlight: true)
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

@Reducer
struct ServerTrustPromptReducer {
    @ObservableState
    struct State: Equatable {
        var prompt: TransmissionTrustPrompt
    }

    enum Action: Equatable {
        case trustConfirmed
        case cancelled
    }

    var body: some ReducerOf<Self> {
        EmptyReducer()
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
