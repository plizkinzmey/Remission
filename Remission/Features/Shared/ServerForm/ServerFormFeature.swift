import ComposableArchitecture
import Foundation

@Reducer
struct ServerFormReducer {
    enum Mode: Equatable, Sendable {
        case add
        case edit(ServerConfig)

        var isEdit: Bool {
            if case .edit = self { return true }
            return false
        }

        var title: String {
            switch self {
            case .add: return L10n.tr("onboarding.title")
            case .edit: return L10n.tr("serverEditor.title")
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var mode: Mode
        var serverConfig: ServerConfigurationReducer.State
        var isSaving: Bool = false
        @Presents var alert: AlertState<AlertAction>?

        init(mode: Mode = .add) {
            self.mode = mode
            switch mode {
            case .add:
                self.serverConfig = .init()
            case .edit(let server):
                self.serverConfig = .init(form: .init(server: server))
            }
        }

        var isSaveButtonDisabled: Bool {
            serverConfig.form.isFormValid == false
                || serverConfig.connectionStatus == .testing
                || (serverConfig.verifiedSubmission == nil && !mode.isEdit)  // Для новых обязателен тест
                || isSaving
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case serverConfig(ServerConfigurationReducer.Action)
        case saveButtonTapped
        case saveResponse(Result<ServerConfig, SaveError>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum Delegate: Equatable {
        case didCreate(ServerConfig)
        case didUpdate(ServerConfig)
        case cancelled
    }

    struct SaveError: Equatable, Error {
        var message: String
    }

    @Dependency(\.credentialsRepository) var credentialsRepository
    @Dependency(\.serverConfigRepository) var serverConfigRepository
    @Dependency(\.uuidGenerator) var uuidGenerator
    @Dependency(\.dateProvider) var dateProvider
    @Dependency(\.onboardingProgressRepository) var onboardingProgressRepository

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.serverConfig, action: \.serverConfig) {
            ServerConfigurationReducer()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .serverConfig:
                return .none

            case .saveButtonTapped:
                return performSave(state: &state)

            case .saveResponse(.success(let server)):
                state.isSaving = false
                switch state.mode {
                case .add:
                    return .send(.delegate(.didCreate(server)))
                case .edit:
                    return .send(.delegate(.didUpdate(server)))
                }

            case .saveResponse(.failure(let error)):
                state.isSaving = false
                state.alert = AlertFactory.simpleAlert(
                    title: state.mode.isEdit
                        ? L10n.tr("serverEditor.alert.saveFailed.title")
                        : L10n.tr("onboarding.alert.saveFailed.title"),
                    message: error.message,
                    action: .dismiss
                )
                return .none

            case .alert(.presented(.dismiss)):
                state.alert = nil
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private func performSave(state: inout State) -> Effect<Action> {
        guard state.isSaving == false else { return .none }
        state.isSaving = true

        let mode = state.mode
        let form = state.serverConfig.form
        let password =
            state.serverConfig.verifiedSubmission?.password
            ?? (form.password.isEmpty ? nil : form.password)

        // Определяем ID и дату создания
        let id: UUID
        let createdAt: Date

        switch mode {
        case .add:
            id = uuidGenerator.generate()
            createdAt = dateProvider.now()
        case .edit(let server):
            id = server.id
            createdAt = server.createdAt
        }

        let config = form.makeServerConfig(id: id, createdAt: createdAt)

        return .run { send in
            do {
                // 1. Сохраняем пароль в Keychain
                if let password = password, let key = config.credentialsKey {
                    let credentials = TransmissionServerCredentials(key: key, password: password)
                    try await credentialsRepository.save(credentials: credentials)
                }

                // 2. Сохраняем конфиг в репозиторий
                _ = try await serverConfigRepository.upsert(config)

                // 3. Если это был онбординг, помечаем как завершенный
                if case .add = mode {
                    onboardingProgressRepository.setCompletedOnboarding(true)
                }

                await send(.saveResponse(.success(config)))
            } catch {
                await send(.saveResponse(.failure(SaveError(message: error.userFacingMessage))))
            }
        }
    }
}
