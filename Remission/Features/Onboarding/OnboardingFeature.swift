import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingReducer {
    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case success(TransmissionHandshakeResult)
        case failed(String)
    }

    @ObservableState
    struct State: Equatable {
        var form: ServerConnectionFormState = .init()
        var validationError: String?
        var isSubmitting: Bool = false
        var pendingWarningFingerprint: String?
        var connectionStatus: ConnectionStatus = .idle
        var pendingSubmission: SubmissionContext?
        var verifiedSubmission: SubmissionContext?
        @Presents var alert: AlertState<AlertAction>?
        @Presents var trustPrompt: TrustPromptReducer.State?
        var isSaveButtonDisabled: Bool {
            form.isFormValid == false || verifiedSubmission == nil || isSubmitting
                || connectionStatus == .testing
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case checkConnectionButtonTapped
        case connectButtonTapped
        case cancelButtonTapped
        case submissionFinished(Result<ServerConfig, SubmissionError>)
        case connectionTestFinished(ConnectionTestResult)
        case alert(PresentationAction<AlertAction>)
        case trustPromptReceived(TransmissionTrustPrompt)
        case trustPrompt(PresentationAction<TrustPromptReducer.Action>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case insecureTransportConfirmed
        case insecureTransportCancelled
        case errorDismissed
    }

    enum ConnectionTestResult: Equatable {
        case success(TransmissionHandshakeResult)
        case failure(String)
    }

    enum Delegate: Equatable {
        case didCreate(ServerConfig)
        case cancelled
    }

    struct SubmissionError: Equatable, Error {
        var message: String
    }

    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.dateProvider) var dateProvider
    @Dependency(\.onboardingProgressRepository) var onboardingProgressRepository
    @Dependency(\.serverConnectionProbe) var serverConnectionProbe
    @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter
    @Dependency(\.httpWarningPreferencesStore) var httpWarningPreferencesStore

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.form.transport):
                state.validationError = nil
                if state.form.transport == .https {
                    state.form.suppressInsecureWarning = false
                    state.pendingWarningFingerprint = nil
                    return .none
                }
                return presentInsecureTransportWarning(state: &state)

            case .binding(\.form.suppressInsecureWarning):
                if let fingerprint = state.form.insecureFingerprint {
                    httpWarningPreferencesStore.setSuppressed(
                        fingerprint,
                        state.form.suppressInsecureWarning
                    )
                }
                return .none

            case .binding:
                state.validationError = nil
                return .none

            case .checkConnectionButtonTapped:
                guard state.connectionStatus != .testing else { return .none }
                guard
                    let context = prepareSubmission(
                        state: &state,
                        forceAllowInsecureTransport: false
                    )
                else {
                    return .none
                }
                return startConnectionProbe(state: &state, context: context)

            case .connectButtonTapped:
                guard let context = state.verifiedSubmission else {
                    state.validationError = "Сначала выполните проверку соединения."
                    return .none
                }
                return persistSubmission(state: &state, context: context)

            case .cancelButtonTapped:
                state.pendingSubmission = nil
                state.verifiedSubmission = nil
                state.connectionStatus = .idle
                return .merge(
                    .cancel(id: OnboardingCancellationID.connectionProbe),
                    .cancel(id: OnboardingCancellationID.trustPrompts),
                    .send(.delegate(.cancelled))
                )

            case .submissionFinished(.success(let server)):
                state.isSubmitting = false
                return .send(.delegate(.didCreate(server)))

            case .submissionFinished(.failure(let error)):
                state.isSubmitting = false
                state.alert = AlertState {
                    TextState("Не удалось добавить сервер")
                } actions: {
                    ButtonState(role: .cancel, action: .errorDismissed) {
                        TextState("Понятно")
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .alert(.presented(.insecureTransportConfirmed)):
                state.alert = nil
                if let context = prepareSubmission(
                    state: &state,
                    forceAllowInsecureTransport: true
                ) {
                    state.pendingWarningFingerprint = nil
                    return startConnectionProbe(state: &state, context: context)
                }
                return .none

            case .alert(.presented(.insecureTransportCancelled)):
                state.alert = nil
                state.pendingWarningFingerprint = nil
                state.form.transport = .https
                return .none

            case .alert(.presented(.errorDismissed)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
                return .none

            case .connectionTestFinished(.success(let handshake)):
                state.connectionStatus = .success(handshake)
                state.verifiedSubmission = state.pendingSubmission
                state.pendingSubmission = nil
                return .merge(
                    .cancel(id: OnboardingCancellationID.connectionProbe),
                    .cancel(id: OnboardingCancellationID.trustPrompts)
                )

            case .connectionTestFinished(.failure(let message)):
                state.connectionStatus = .failed(message)
                state.pendingSubmission = nil
                state.verifiedSubmission = nil
                return .merge(
                    .cancel(id: OnboardingCancellationID.connectionProbe),
                    .cancel(id: OnboardingCancellationID.trustPrompts)
                )

            case .trustPromptReceived(let prompt):
                state.trustPrompt = TrustPromptReducer.State(prompt: prompt)
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

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$trustPrompt, action: \.trustPrompt) {
            TrustPromptReducer()
        }
    }
}

extension OnboardingReducer {
    typealias SubmissionContext = OnboardingSubmissionContext
    typealias TrustPromptReducer = OnboardingTrustPromptReducer
}

private enum OnboardingCancellationID: Hashable {
    case connectionProbe
    case trustPrompts
}

extension OnboardingReducer {
    fileprivate func startConnectionProbe(
        state: inout State,
        context: SubmissionContext
    ) -> Effect<Action> {
        state.pendingSubmission = context
        state.connectionStatus = .testing
        state.verifiedSubmission = nil
        return .merge(
            .run { [context] send in
                do {
                    let result = try await serverConnectionProbe.run(
                        .init(server: context.server, password: context.password),
                        trustPromptCenter.makeHandler()
                    )
                    await send(.connectionTestFinished(.success(result.handshake)))
                } catch let probeError as ServerConnectionProbe.ProbeError {
                    await send(
                        .connectionTestFinished(.failure(probeError.displayMessage))
                    )
                } catch {
                    await send(.connectionTestFinished(.failure(describe(error))))
                }
            }
            .cancellable(id: OnboardingCancellationID.connectionProbe, cancelInFlight: true),
            listenForTrustPrompts()
        )
    }

    private func listenForTrustPrompts() -> Effect<Action> {
        .run { send in
            for await prompt in trustPromptCenter.prompts {
                await send(.trustPromptReceived(prompt))
            }
        }
        .cancellable(id: OnboardingCancellationID.trustPrompts, cancelInFlight: true)
    }

    fileprivate func persistSubmission(
        state: inout State,
        context: SubmissionContext
    ) -> Effect<Action> {
        guard state.isSubmitting == false else { return .none }
        state.isSubmitting = true
        return .run { [context] send in
            do {
                if let password = context.password {
                    if let credentialsKey = context.server.credentialsKey {
                        let credentials = TransmissionServerCredentials(
                            key: credentialsKey,
                            password: password
                        )
                        try await credentialsRepository.save(credentials: credentials)
                    }
                }
                onboardingProgressRepository.setCompletedOnboarding(true)
                await send(.submissionFinished(.success(context.server)))
            } catch {
                await send(
                    .submissionFinished(
                        .failure(SubmissionError(message: describe(error)))
                    )
                )
            }
        }
    }

    fileprivate func prepareSubmission(
        state: inout State,
        forceAllowInsecureTransport: Bool
    ) -> SubmissionContext? {
        guard state.form.isFormValid, state.form.portValue != nil else {
            state.validationError = "Заполните хост и корректный порт."
            return nil
        }

        let context = makeSubmissionContext(state: state)

        if context.server.usesInsecureTransport {
            let fingerprint = context.insecureFingerprint ?? ""
            if state.form.suppressInsecureWarning {
                httpWarningPreferencesStore.setSuppressed(fingerprint, true)
            }

            if forceAllowInsecureTransport {
                httpWarningPreferencesStore.setSuppressed(fingerprint, true)
            } else {
                let isSuppressed = httpWarningPreferencesStore.isSuppressed(fingerprint)
                if isSuppressed == false {
                    state.pendingWarningFingerprint = fingerprint
                    state.alert = makeInsecureTransportAlert()
                    return nil
                }
            }
        }

        state.validationError = nil
        state.pendingWarningFingerprint = nil
        return context
    }

    fileprivate func makeSubmissionContext(
        state: State
    ) -> SubmissionContext {
        let id = uuidGenerator.generate()
        let date = dateProvider.now()
        let server = state.form.makeServerConfig(id: id, createdAt: date)

        let password = state.form.password.isEmpty ? nil : state.form.password
        let fingerprint: String? =
            server.usesInsecureTransport
            ? ServerConfig.makeFingerprint(
                host: server.connection.host,
                port: server.connection.port,
                username: state.form.username
            )
            : nil

        return SubmissionContext(
            server: server, password: password, insecureFingerprint: fingerprint)
    }

    private func presentInsecureTransportWarning(
        state: inout State
    ) -> Effect<Action> {
        guard state.form.transport == .http else { return .none }
        guard let fingerprint = state.form.insecureFingerprint else { return .none }
        if httpWarningPreferencesStore.isSuppressed(fingerprint) {
            return .none
        }
        state.pendingWarningFingerprint = fingerprint
        state.alert = makeInsecureTransportAlert()
        return .none
    }

    private func makeInsecureTransportAlert() -> AlertState<AlertAction> {
        AlertState {
            TextState("Небезопасное подключение")
        } actions: {
            ButtonState(role: .destructive, action: .insecureTransportConfirmed) {
                TextState("Продолжить")
            }
            ButtonState(role: .cancel, action: .insecureTransportCancelled) {
                TextState("Отмена")
            }
        } message: {
            TextState(
                "Соединение без шифрования. Логин и пароль могут быть перехвачены. Продолжить?"
            )
        }
    }

    fileprivate func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let rawMessage =
            nsError.localizedDescription.isEmpty
            ? String(describing: error)
            : nsError.localizedDescription
        return localizeConnectionMessage(rawMessage)
    }

    private func localizeConnectionMessage(_ message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return
                "Истекло время ожидания подключения. Проверьте сеть или сервер и попробуйте снова."
        }
        if lowercased.contains("cancelled") || lowercased.contains("canceled") {
            return "Проверка подключения была отменена. Попробуйте ещё раз."
        }
        return message
    }
}

struct OnboardingSubmissionContext: Equatable, Sendable {
    var server: ServerConfig
    var password: String?
    var insecureFingerprint: String?
}

@Reducer
struct OnboardingTrustPromptReducer {
    @ObservableState
    struct State: Equatable {
        var prompt: TransmissionTrustPrompt
    }

    enum Action: Equatable {
        case trustConfirmed
        case cancelled
    }

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .trustConfirmed, .cancelled:
                return .none
            }
        }
    }
}
