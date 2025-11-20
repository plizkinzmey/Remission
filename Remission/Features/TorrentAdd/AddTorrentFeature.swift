import ComposableArchitecture
import Foundation

@Reducer
struct AddTorrentReducer {
    @ObservableState
    struct State: Equatable {
        var pendingInput: PendingTorrentInput
        var connectionEnvironment: ServerConnectionEnvironment?
        var destinationPath: String = ""
        var startPaused: Bool = false
        var tags: [String] = []
        var newTag: String = ""
        var isSubmitting: Bool = false
        var closeOnAlertDismiss: Bool = false
        @Presents var alert: AlertState<AlertAction>?
    }

    enum Action: Equatable {
        case destinationPathChanged(String)
        case startPausedChanged(Bool)
        case newTagChanged(String)
        case addTagTapped
        case removeTag(String)
        case submitButtonTapped
        case submitResponse(Result<SubmitResult, SubmitError>)
        case closeButtonTapped
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case closeRequested
        case addCompleted(TorrentRepository.AddResult)
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    struct SubmitResult: Equatable {
        var addResult: TorrentRepository.AddResult
    }

    enum SubmitError: Equatable, Error {
        case unauthorized
        case sessionConflict
        case mapping(String)
        case failed(String)

        var message: String {
            switch self {
            case .unauthorized:
                return "Проверьте логин/пароль и повторите попытку."
            case .sessionConflict:
                return "Сессия устарела. Попробуйте снова подключиться и повторить добавление."
            case .mapping(let details):
                return "Некорректный ответ Transmission: \(details)"
            case .failed(let value):
                return value
            }
        }
    }

    @Dependency(\.torrentRepository) var torrentRepository

    private enum AddTorrentCancelID {
        case submit
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .destinationPathChanged(let value):
                state.destinationPath = value
                return .none

            case .startPausedChanged(let value):
                state.startPaused = value
                return .none

            case .newTagChanged(let value):
                state.newTag = value
                return .none

            case .addTagTapped:
                let tag = state.newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard tag.isEmpty == false else {
                    return .none
                }
                if state.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                    state.newTag = ""
                    return .none
                }
                state.tags.append(tag)
                state.newTag = ""
                return .none

            case .removeTag(let tag):
                state.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                return .none

            case .submitButtonTapped:
                return handleSubmit(state: &state)

            case .submitResponse(.success(let result)):
                state.isSubmitting = false
                state.closeOnAlertDismiss = true
                state.alert = successAlert(for: result.addResult)
                return .send(.delegate(.addCompleted(result.addResult)))

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
                state.closeOnAlertDismiss = false
                state.alert = AlertState {
                    TextState("Не удалось добавить торрент")
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState("Понятно")
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .closeButtonTapped:
                return .send(.delegate(.closeRequested))

            case .alert(.presented(.dismiss)):
                state.alert = nil
                let shouldClose = state.closeOnAlertDismiss
                state.closeOnAlertDismiss = false
                return shouldClose ? .send(.delegate(.closeRequested)) : .none

            case .alert(.dismiss):
                return .none

            case .alert:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    // swiftlint:disable function_body_length
    private func handleSubmit(state: inout State) -> Effect<Action> {
        let input = state.pendingInput
        let destination = state.destinationPath.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard destination.isEmpty == false else {
            state.alert = AlertState {
                TextState("Укажите каталог загрузки")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Поле каталога загрузки не может быть пустым.")
            }
            state.closeOnAlertDismiss = false
            return .none
        }

        guard let environment = state.connectionEnvironment else {
            state.alert = AlertState {
                TextState("Нет подключения к серверу")
            } actions: {
                ButtonState(role: .cancel, action: .dismiss) {
                    TextState("Понятно")
                }
            } message: {
                TextState("Не удалось получить окружение подключения. Повторите попытку позже.")
            }
            state.closeOnAlertDismiss = false
            return .none
        }

        let tags = state.tags.isEmpty ? nil : state.tags
        let startPaused = state.startPaused
        state.isSubmitting = true
        state.closeOnAlertDismiss = false

        return .run { send in
            let result = await Result {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    try await torrentRepository.add(
                        input,
                        destinationPath: destination,
                        startPaused: startPaused,
                        tags: tags
                    )
                }
            }

            switch result {
            case .success(let response):
                await send(.submitResponse(.success(.init(addResult: response))))
            case .failure(let error):
                await send(.submitResponse(.failure(mapSubmitError(error))))
            }
        }
        .cancellable(id: AddTorrentCancelID.submit, cancelInFlight: true)
    }
    // swiftlint:enable function_body_length

    private func successAlert(
        for result: TorrentRepository.AddResult
    ) -> AlertState<AlertAction> {
        let isDuplicate: Bool = result.status == .duplicate
        let title: TextState =
            isDuplicate
            ? TextState("Торрент уже добавлен")
            : TextState("Торрент добавлен")
        let message: TextState =
            isDuplicate
            ? TextState("Переданный торрент уже есть в списке: \(result.name)")
            : TextState("Добавлен торрент \(result.name)")

        return AlertState {
            title
        } actions: {
            ButtonState(role: .cancel, action: .dismiss) {
                TextState("Понятно")
            }
        } message: {
            message
        }
    }

    private func mapSubmitError(_ error: Error) -> SubmitError {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized:
                return .unauthorized
            case .sessionConflict:
                return .sessionConflict
            default:
                return .failed(apiError.localizedDescription)
            }
        }

        if let mappingError = error as? DomainMappingError {
            return .mapping(mappingError.localizedDescription)
        }

        return .failed(error.localizedDescription)
    }
}
