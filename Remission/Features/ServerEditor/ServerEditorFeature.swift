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
    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
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
                return persistChanges(state: &state)

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
