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
        var pendingWarningFingerprint: String?
        @Presents var alert: AlertState<AlertAction>?

        init(server: ServerConfig, password: String? = nil) {
            self.server = server
            var form = ServerConnectionFormState()
            form.load(from: server, password: password)
            self.form = form
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case task
        case saveButtonTapped
        case cancelButtonTapped
        case credentialsLoaded(String?)
        case saveCompleted(Result<ServerConfig, EditorError>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case insecureTransportConfirmed
        case insecureTransportCancelled
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
                if let password {
                    state.form.password = password
                }
                return .none

            case .saveButtonTapped:
                guard state.form.isFormValid else {
                    state.validationError = L10n.tr("onboarding.error.validation.hostPort")
                    return .none
                }
                return persistChanges(state: &state, forceAllowInsecureTransport: false)

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

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

            case .alert(.presented(.insecureTransportConfirmed)):
                state.alert = nil
                state.pendingWarningFingerprint = nil
                return persistChanges(state: &state, forceAllowInsecureTransport: true)

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

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
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

    private func persistChanges(
        state: inout State,
        forceAllowInsecureTransport: Bool
    ) -> Effect<Action> {
        guard state.isSaving == false else { return .none }

        if state.form.usesInsecureTransport {
            if let fingerprint = state.form.insecureFingerprint {
                if state.form.suppressInsecureWarning {
                    httpWarningPreferencesStore.setSuppressed(fingerprint, true)
                }

                if forceAllowInsecureTransport == false {
                    let isSuppressed = httpWarningPreferencesStore.isSuppressed(fingerprint)
                    if isSuppressed == false {
                        state.pendingWarningFingerprint = fingerprint
                        state.alert = makeInsecureTransportAlert()
                        return .none
                    }
                } else {
                    httpWarningPreferencesStore.setSuppressed(fingerprint, true)
                }
            }
        }

        let originalServer = state.server
        let updatedServer = state.form.makeServerConfig(
            id: originalServer.id,
            createdAt: originalServer.createdAt
        )
        let password = state.form.password.isEmpty ? nil : state.form.password
        state.validationError = nil
        state.pendingWarningFingerprint = nil
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

    private func makeInsecureTransportAlert() -> AlertState<AlertAction> {
        AlertState {
            TextState(L10n.tr("onboarding.alert.insecureConnection.title"))
        } actions: {
            ButtonState(role: .destructive, action: .insecureTransportConfirmed) {
                TextState(L10n.tr("onboarding.alert.insecureConnection.proceed"))
            }
            ButtonState(role: .cancel, action: .insecureTransportCancelled) {
                TextState(L10n.tr("common.cancel"))
            }
        } message: {
            TextState(
                L10n.tr("onboarding.alert.insecureConnection.message")
            )
        }
    }
}
