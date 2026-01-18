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
        var serverID: UUID?
        var pendingInput: PendingTorrentInput?
        var connectionEnvironment: ServerConnectionEnvironment?
        var source: Source = .torrentFile
        var magnetText: String = ""
        var selectedFileName: String?
        var isFileImporterPresented: Bool = false
        var destinationPath: String = ""
        var serverDownloadDirectory: String = ""
        var recentDownloadDirectories: [String] = []
        var startPaused: Bool = false
        var category: TorrentCategory = .other
        var isSubmitting: Bool = false
        var closeOnAlertDismiss: Bool = false
        @Presents var alert: AlertState<AlertAction>?

        init(
            pendingInput: PendingTorrentInput? = nil,
            connectionEnvironment: ServerConnectionEnvironment? = nil,
            serverID: UUID? = nil
        ) {
            self.serverID = serverID
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
        case destinationSuggestionSelected(String)
        case destinationSuggestionDeleted(String)
        case startPausedChanged(Bool)
        case categoryChanged(TorrentCategory)
        case submitButtonTapped
        case submitResponse(Result<SubmitResult, SubmitError>)
        case defaultDownloadDirectoryResponse(TaskResult<String>)
        case preferencesResponse(TaskResult<UserPreferences>)
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
    @Dependency(\.userPreferencesRepository) var userPreferencesRepository

    enum AddTorrentCancelID {
        case submit
        case loadDefaults
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                var effects: [Effect<Action>] = []
                if state.destinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let environment = state.connectionEnvironment {
                        effects.append(loadDefaultDownloadDirectory(environment: environment))
                    }
                }
                if let serverID = state.serverID {
                    effects.append(loadPreferences(serverID: serverID))
                }
                return .merge(effects)

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
                return persistRecentDownloadDirectories(state: &state)

            case .destinationSuggestionSelected(let value):
                state.destinationPath = value
                return .none

            case .destinationSuggestionDeleted(let value):
                state.recentDownloadDirectories.removeAll { $0 == value }
                if state.destinationPath == value {
                    let fallback = state.serverDownloadDirectory
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    state.destinationPath = fallback
                }
                return persistRecentDownloadDirectories(state: &state)

            case .startPausedChanged(let value):
                state.startPaused = value
                return .none

            case .categoryChanged(let category):
                state.category = category
                return .none

            case .submitButtonTapped:
                return handleSubmit(state: &state)

            case .submitResponse(.success(let result)):
                state.isSubmitting = false
                state.closeOnAlertDismiss = true
                state.alert = successAlert(for: result.addResult)
                return .merge(
                    .send(.delegate(.addCompleted(result.addResult))),
                    persistRecentDownloadDirectories(state: &state)
                )

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
                state.recentDownloadDirectories = normalizedRecentDirectories(
                    state.recentDownloadDirectories,
                    defaultDirectory: directory
                )
                return .none

            case .defaultDownloadDirectoryResponse(.failure):
                return .none

            case .preferencesResponse(.success(let preferences)):
                state.recentDownloadDirectories = normalizedRecentDirectories(
                    preferences.recentDownloadDirectories,
                    defaultDirectory: state.serverDownloadDirectory
                )
                return .none

            case .preferencesResponse(.failure):
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
