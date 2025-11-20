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
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    struct SubmitResult: Equatable {}

    enum SubmitError: Equatable, Error {
        case failed(String)

        var message: String {
            switch self {
            case .failed(let value):
                return value
            }
        }
    }

    @Dependency(\.transmissionClient) var transmissionClient

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

            case .submitResponse(.success):
                state.isSubmitting = false
                return .send(.delegate(.closeRequested))

            case .submitResponse(.failure(let error)):
                state.isSubmitting = false
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
                return .none

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
            return .none
        }

        let tags = state.tags.isEmpty ? nil : state.tags
        let startPaused = state.startPaused
        state.isSubmitting = true

        return .run { send in
            await send(
                .submitResponse(
                    Result {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            switch input.payload {
                            case .torrentFile(let data, _):
                                _ = try await transmissionClient.torrentAdd(
                                    nil,
                                    data,
                                    destination,
                                    startPaused,
                                    tags
                                )
                            case .magnetLink(_, let rawValue):
                                _ = try await transmissionClient.torrentAdd(
                                    rawValue,
                                    nil,
                                    destination,
                                    startPaused,
                                    tags
                                )
                            }
                        }
                    }
                    .map { _ in SubmitResult() }
                    .mapError { SubmitError.failed($0.localizedDescription) }
                )
            )
        }
        .cancellable(id: AddTorrentCancelID.submit, cancelInFlight: true)
    }
}
