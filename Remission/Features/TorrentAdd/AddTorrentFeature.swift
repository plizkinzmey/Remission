import ComposableArchitecture
import Foundation

@Reducer
struct AddTorrentReducer {
    enum Source: String, CaseIterable, Equatable, Sendable {
        case torrentFile
        case magnetLink
    }

    enum FileImportResult: Equatable {
        case success(URL)
        case failure(String)
    }

    enum FileImportError: Equatable, Error {
        case failed(String)

        var message: String {
            switch self {
            case .failed(let message):
                return message
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var pendingInput: PendingTorrentInput?
        var connectionEnvironment: ServerConnectionEnvironment?
        var source: Source = .torrentFile
        var magnetText: String = ""
        var selectedFileName: String?
        var isFileImporterPresented: Bool = false
        var destinationPath: String = ""
        var serverDownloadDirectory: String = ""
        var startPaused: Bool = false
        var tags: [String] = []
        var newTag: String = ""
        var isSubmitting: Bool = false
        var closeOnAlertDismiss: Bool = false
        @Presents var alert: AlertState<AlertAction>?

        init(
            pendingInput: PendingTorrentInput? = nil,
            connectionEnvironment: ServerConnectionEnvironment? = nil
        ) {
            self.pendingInput = pendingInput
            self.connectionEnvironment = connectionEnvironment
            guard let pendingInput else { return }
            switch pendingInput.payload {
            case .torrentFile(_, let fileName):
                source = .torrentFile
                selectedFileName = fileName ?? pendingInput.sourceDescription
            case .magnetLink(_, let rawValue):
                source = .magnetLink
                magnetText = rawValue
            }
        }
    }

    enum Action: Equatable {
        case task
        case sourceChanged(Source)
        case magnetTextChanged(String)
        case chooseFileTapped
        case fileImporterPresented(Bool)
        case fileImportResult(FileImportResult)
        case fileImportLoaded(Result<PendingTorrentInput, FileImportError>)
        case destinationPathChanged(String)
        case startPausedChanged(Bool)
        case newTagChanged(String)
        case addTagTapped
        case removeTag(String)
        case submitButtonTapped
        case submitResponse(Result<SubmitResult, SubmitError>)
        case defaultDownloadDirectoryResponse(TaskResult<String>)
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
                return L10n.tr("torrentAdd.error.auth")
            case .sessionConflict:
                return L10n.tr("torrentAdd.error.session")
            case .mapping(let details):
                return String(
                    format: L10n.tr("torrentAdd.error.badResponse"),
                    details
                )
            case .failed(let value):
                return value
            }
        }
    }

    @Dependency(\.torrentRepository) var torrentRepository
    @Dependency(\.sessionRepository) var sessionRepository
    @Dependency(\.torrentFileLoader) var torrentFileLoader

    enum AddTorrentCancelID {
        case submit
        case loadDefaults
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard
                    state.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    let environment = state.connectionEnvironment
                else {
                    return .none
                }

                return .run { send in
                    await send(
                        .defaultDownloadDirectoryResponse(
                            TaskResult {
                                try await withDependencies {
                                    environment.apply(to: &$0)
                                } operation: {
                                    let state = try await sessionRepository.fetchState()
                                    return state.downloadDirectory
                                }
                            }
                        )
                    )
                }
                .cancellable(id: AddTorrentCancelID.loadDefaults, cancelInFlight: true)

            case .sourceChanged(let source):
                state.source = source
                if source == .magnetLink {
                    state.selectedFileName = nil
                    state.pendingInput = pendingInput(fromMagnet: state.magnetText)
                } else {
                    state.magnetText = ""
                    state.pendingInput = nil
                }
                return .none

            case .magnetTextChanged(let value):
                state.magnetText = value
                if state.source == .magnetLink {
                    state.pendingInput = pendingInput(fromMagnet: value)
                }
                return .none

            case .chooseFileTapped:
                state.isFileImporterPresented = true
                return .none

            case .fileImporterPresented(let isPresented):
                state.isFileImporterPresented = isPresented
                return .none

            case .fileImportResult(.success(let url)):
                return handleFileImport(url: url, state: &state)

            case .fileImportResult(.failure(let message)):
                return handleFileImportFailure(message: message, state: &state)

            case .fileImportLoaded(.success(let input)):
                return handleFileImportLoaded(result: .success(input), state: &state)

            case .fileImportLoaded(.failure(let error)):
                return handleFileImportLoaded(result: .failure(error), state: &state)

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
                    TextState(L10n.tr("torrentAdd.alert.addFailed.title"))
                } actions: {
                    ButtonState(role: .cancel, action: .dismiss) {
                        TextState(L10n.tr("common.ok"))
                    }
                } message: {
                    TextState(error.message)
                }
                return .none

            case .defaultDownloadDirectoryResponse(.success(let directory)):
                state.serverDownloadDirectory = directory
                if state.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.destinationPath = directory
                }
                return .none

            case .defaultDownloadDirectoryResponse(.failure):
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
}
