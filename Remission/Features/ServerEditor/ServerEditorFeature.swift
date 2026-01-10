import ComposableArchitecture
import Foundation

@Reducer
struct ServerEditorReducer {
    @ObservableState
    struct State: Equatable {
        var server: ServerConfig
        var form: ServerConnectionFormState
        var validationError: String?
        var isSaving: Bool = false
        var hasLoadedCredentials: Bool = false
        var originalPassword: String?
        var connectionStatus: ConnectionStatus = .idle
        var pendingSubmission: SubmissionContext?
        var verifiedSubmission: SubmissionContext?
        @Presents var alert: AlertState<AlertAction>?

        init(server: ServerConfig, password: String? = nil) {
            self.server = server
            var form = ServerConnectionFormState()
            form.load(from: server, password: password)
            self.form = form
            self.originalPassword = password
        }

        var requiresConnectionCheck: Bool {
            let currentServer = form.makeServerConfig(id: server.id, createdAt: server.createdAt)
            let originalUsername = server.authentication?.username ?? ""
            let currentUsername = currentServer.authentication?.username ?? ""
            let passwordChanged = (originalPassword ?? "") != form.password
            return currentServer.connection != server.connection
                || currentServer.security != server.security
                || currentUsername != originalUsername
                || passwordChanged
        }

        var isSaveButtonDisabled: Bool {
            isSaving
                || form.isFormValid == false
                || connectionStatus == .testing
                || (requiresConnectionCheck && verifiedSubmission == nil)
        }
    }

    enum ConnectionStatus: Equatable {
        case idle
        case testing
        case success(TransmissionHandshakeResult)
        case failed(String)
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case task
        case checkConnectionButtonTapped
        case saveButtonTapped
        case cancelButtonTapped
        case credentialsLoaded(String?)
        case connectionTestFinished(ConnectionTestResult)
        case saveCompleted(Result<ServerConfig, EditorError>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case errorDismissed
    }

    enum Delegate: Equatable {
        case didUpdate(ServerConfig)
        case cancelled
    }

    struct EditorError: Equatable, Error {
        var message: String
    }

    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.serverConnectionProbe) var serverConnectionProbe

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                state.validationError = nil
                resetVerificationIfNeeded(state: &state)
                return .none

            case .task:
                guard state.hasLoadedCredentials == false else { return .none }
                state.hasLoadedCredentials = true
                guard let key = state.server.credentialsKey else { return .none }
                return .run { send in
                    do {
                        let credentials = try await credentialsRepository.load(key: key)
                        await send(.credentialsLoaded(credentials?.password))
                    } catch {
                        await send(.credentialsLoaded(nil))
                    }
                }

            case .credentialsLoaded(let password):
                state.form.password = password ?? ""
                state.originalPassword = password
                resetVerificationIfNeeded(state: &state)
                return .none

            case .checkConnectionButtonTapped:
                guard state.connectionStatus != .testing else { return .none }
                guard let context = prepareSubmission(state: &state) else { return .none }
                return startConnectionProbe(state: &state, context: context)

            case .saveButtonTapped:
                guard state.form.isFormValid else {
                    state.validationError = L10n.tr("onboarding.error.validation.hostPort")
                    return .none
                }
                if state.requiresConnectionCheck && state.verifiedSubmission == nil {
                    state.validationError = L10n.tr("onboarding.error.validation.checkRequired")
                    return .none
                }
                return persistChanges(state: &state)

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case .connectionTestFinished(.success(let handshake)):
                state.connectionStatus = .success(handshake)
                state.verifiedSubmission = state.pendingSubmission
                state.pendingSubmission = nil
                return .none

            case .connectionTestFinished(.failure(let message)):
                state.connectionStatus = .failed(message)
                state.pendingSubmission = nil
                state.verifiedSubmission = nil
                return .none

            case .saveCompleted(.success(let server)):
                state.isSaving = false
                state.server = server
                return .send(.delegate(.didUpdate(server)))

            case .saveCompleted(.failure(let error)):
                state.isSaving = false
                state.alert = AlertState {
                    TextState(L10n.tr("serverEditor.alert.saveFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .errorDismissed) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .alert(.presented(.errorDismissed)):
                state.alert = nil
                return .none

            case .alert(.dismiss):
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func prepareSubmission(
        state: inout State
    ) -> SubmissionContext? {
        guard state.form.isFormValid, state.form.portValue != nil else {
            state.validationError = L10n.tr("onboarding.error.validation.hostPort")
            return nil
        }
        state.validationError = nil
        return makeSubmissionContext(state: state)
    }

    private func makeSubmissionContext(
        state: State
    ) -> SubmissionContext {
        let server = state.form.makeServerConfig(
            id: state.server.id,
            createdAt: state.server.createdAt
        )
        let password = state.form.password.isEmpty ? nil : state.form.password
        return SubmissionContext(server: server, password: password)
    }

    private func startConnectionProbe(
        state: inout State,
        context: SubmissionContext
    ) -> Effect<Action> {
        state.pendingSubmission = context
        state.connectionStatus = .testing
        state.verifiedSubmission = nil
        return .run { [context] send in
            do {
                let result = try await serverConnectionProbe.run(
                    .init(server: context.server, password: context.password),
                    nil
                )
                await send(.connectionTestFinished(.success(result.handshake)))
            } catch let probeError as ServerConnectionProbe.ProbeError {
                await send(.connectionTestFinished(.failure(probeError.displayMessage)))
            } catch {
                await send(.connectionTestFinished(.failure(describe(error))))
            }
        }
    }

    private func resetVerificationIfNeeded(state: inout State) {
        guard let verified = state.verifiedSubmission else { return }
        let currentServer = state.form.makeServerConfig(
            id: state.server.id,
            createdAt: state.server.createdAt
        )
        let currentPassword = state.form.password.isEmpty ? nil : state.form.password
        if currentServer.connection != verified.server.connection
            || currentServer.security != verified.server.security
            || currentServer.authentication?.username != verified.server.authentication?.username
            || currentPassword != verified.password {
            state.connectionStatus = .idle
            state.pendingSubmission = nil
            state.verifiedSubmission = nil
        }
    }

    private func describe(_ error: Error) -> String {
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
            return L10n.tr("onboarding.connection.timeout")
        }
        if lowercased.contains("cancelled") || lowercased.contains("canceled") {
            return L10n.tr("onboarding.connection.cancelled")
        }
        return message
    }

    private func persistChanges(
        state: inout State
    ) -> Effect<Action> {
        guard state.isSaving == false else { return .none }

        let originalServer = state.server
        let updatedServer = state.form.makeServerConfig(
            id: originalServer.id,
            createdAt: originalServer.createdAt
        )
        let password = state.form.password.isEmpty ? nil : state.form.password
        state.validationError = nil
        state.isSaving = true

        return .run { send in
            do {
                _ = try await serverConfigRepository.upsert(updatedServer)

                let previousKey = originalServer.credentialsKey
                let nextKey = updatedServer.credentialsKey

                if let password = password, let key = nextKey {
                    let credentials = TransmissionServerCredentials(key: key, password: password)
                    try await credentialsRepository.save(credentials: credentials)
                    if let previousKey, previousKey != key {
                        try await credentialsRepository.delete(key: previousKey)
                    }
                } else if let key = previousKey {
                    try await credentialsRepository.delete(key: key)
                }

                await send(.saveCompleted(.success(updatedServer)))
            } catch {
                await send(
                    .saveCompleted(
                        .failure(EditorError(message: (error as NSError).localizedDescription))
                    )
                )
            }
        }
    }
}

extension ServerEditorReducer {
    struct SubmissionContext: Equatable, Sendable {
        var server: ServerConfig
        var password: String?
    }

    enum ConnectionTestResult: Equatable {
        case success(TransmissionHandshakeResult)
        case failure(String)
    }
}
