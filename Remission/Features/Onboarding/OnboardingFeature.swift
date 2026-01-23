import ComposableArchitecture
import Foundation

@Reducer
struct OnboardingReducer {
    @ObservableState
    struct State: Equatable {
        var serverConfig: ServerConfigurationReducer.State = .init()
        var isSubmitting: Bool = false
        var verifiedSubmission: ServerSubmissionContext?
        @Presents var alert: AlertState<AlertAction>?

        var isSaveButtonDisabled: Bool {
            serverConfig.form.isFormValid == false || verifiedSubmission == nil || isSubmitting
                || serverConfig.connectionStatus == .testing
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case serverConfig(ServerConfigurationReducer.Action)
        case connectButtonTapped
        case cancelButtonTapped
        case submissionFinished(Result<ServerConfig, SubmissionError>)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum AlertAction: Equatable {
        case errorDismissed
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

    var body: some Reducer<State, Action> {
        BindingReducer()

        Scope(state: \.serverConfig, action: \.serverConfig) {
            ServerConfigurationReducer()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .serverConfig(.delegate(.connectionVerified(let context))):
                state.verifiedSubmission = context
                return .none

            case .serverConfig(.delegate(.formChanged)):
                state.verifiedSubmission = nil
                return .none

            case .serverConfig:
                return .none

            case .connectButtonTapped:
                guard let context = state.verifiedSubmission else {
                    state.serverConfig.validationError = L10n.tr(
                        "onboarding.error.validation.checkRequired")
                    return .none
                }
                return persistSubmission(state: &state, context: context)

            case .cancelButtonTapped:
                return .send(.delegate(.cancelled))

            case .submissionFinished(.success(let server)):
                state.isSubmitting = false
                return .send(.delegate(.didCreate(server)))

            case .submissionFinished(.failure(let error)):
                state.isSubmitting = false
                state.alert = AlertState {
                    TextState(L10n.tr("onboarding.alert.saveFailed.title"))
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
    }
}

extension OnboardingReducer {
    fileprivate func persistSubmission(
        state: inout State,
        context: ServerSubmissionContext
    ) -> Effect<Action> {
        guard state.isSubmitting == false else { return .none }
        state.isSubmitting = true

        // Generate real ID and Date for the new server
        let id = uuidGenerator.generate()
        let date = dateProvider.now()
        let server = state.serverConfig.form.makeServerConfig(id: id, createdAt: date)
        let password = context.password

        return .run { send in
            do {
                if let password = password {
                    if let credentialsKey = server.credentialsKey {
                        let credentials = TransmissionServerCredentials(
                            key: credentialsKey,
                            password: password
                        )
                        try await credentialsRepository.save(credentials: credentials)
                    }
                }
                onboardingProgressRepository.setCompletedOnboarding(true)
                await send(.submissionFinished(.success(server)))
            } catch {
                await send(
                    .submissionFinished(
                        .failure(
                            SubmissionError(message: ServerConnectionErrorHelper.describe(error)))
                    )
                )
            }
        }
    }
}
