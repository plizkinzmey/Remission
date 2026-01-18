import ComposableArchitecture
import Foundation

@Reducer
struct TorrentDetailReducer {
    enum Action: Equatable {
        case task
        case teardown
        case refreshRequested
        case detailsResponse(TaskResult<DetailsResponse>)
        case commandResponse(CommandResult)
        case startTapped
        case pauseTapped
        case verifyTapped
        case removeButtonTapped
        case removeConfirmation(PresentationAction<RemoveConfirmationAction>)
        case priorityChanged(fileIndices: [Int], priority: Int)
        case toggleDownloadLimit(Bool)
        case toggleUploadLimit(Bool)
        case downloadLimitChanged(Int)
        case uploadLimitChanged(Int)
        case categoryChanged(TorrentCategory)
        case categoryUpdateResponse(CategoryUpdateResult)
        case commandDidFinish(String)
        case commandFailed(String)
        case dismissError
        case errorPresenter(ErrorPresenter<ErrorRetry>.Action)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    struct DetailsResponse: Equatable {
        var torrent: Torrent
        var timestamp: Date
    }

    enum AlertAction: Equatable {
        case dismiss
    }

    enum RemoveConfirmationAction: Equatable {
        case deleteTorrentOnly
        case deleteWithData
        case cancel
    }

    enum Delegate: Equatable {
        case closeRequested
        case torrentUpdated(Torrent)
        case torrentRemoved(Torrent.Identifier)
    }

    enum CommandCategory: Equatable {
        case start
        case pause
        case verify
        case remove
        case priority
    }

    enum CommandKind: Equatable {
        case start
        case pause
        case verify
        case remove(deleteData: Bool)
        case priority(indices: [Int], priority: TorrentRepository.FilePriority)

        var category: CommandCategory {
            switch self {
            case .start:
                return .start
            case .pause:
                return .pause
            case .verify:
                return .verify
            case .remove:
                return .remove
            case .priority:
                return .priority
            }
        }
    }

    enum CommandResult: Equatable {
        case success(CommandKind)
        case failure(CommandKind, String)
    }

    enum ErrorRetry: Equatable {
        case reloadDetails
        case command(CommandKind)
    }

    enum CategoryUpdateResult: Equatable {
        case success
        case failure(String)
    }

    @Dependency(\.dateProvider) var dateProvider

    enum FetchTrigger {
        case initial
        case manual
    }

    enum CancelID: Hashable {
        case loadTorrentDetails
        case commandExecution
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return loadDetails(state: &state, trigger: .initial)

            case .refreshRequested:
                return loadDetails(state: &state, trigger: .manual)

            case .teardown:
                state.isLoading = false
                state.pendingCommands.removeAll()
                state.activeCommand = nil
                state.pendingListSync = false
                return .merge(
                    .cancel(id: CancelID.loadTorrentDetails),
                    .cancel(id: CancelID.commandExecution)
                )

            case .detailsResponse(.success(let response)):
                state.isLoading = false
                state.errorPresenter.banner = nil
                state.apply(response.torrent)
                state.speedHistory.append(
                    timestamp: response.timestamp,
                    downloadRate: state.rateDownload,
                    uploadRate: state.rateUpload
                )
                if state.pendingListSync {
                    state.pendingListSync = false
                    return .send(.delegate(.torrentUpdated(response.torrent)))
                }
                return .none

            case .detailsResponse(.failure(let error)):
                state.isLoading = false
                let message = Self.describe(error)
                state.errorPresenter.banner = .init(
                    message: message,
                    retry: .reloadDetails
                )
                state.pendingListSync = false
                return .none

            case .commandResponse(.success(let command)):
                state.activeCommand = nil
                if Self.shouldSyncList(after: command) {
                    state.pendingListSync = true
                }
                let torrentID = state.torrentID
                let next = startNextCommand(state: &state)
                return .merge(
                    commandSuccessEffect(for: command, torrentID: torrentID),
                    next
                )

            case .commandResponse(.failure(_, let message)):
                state.activeCommand = nil
                state.pendingListSync = false
                let next = startNextCommand(state: &state)
                return .merge(.send(.commandFailed(message)), next)

            case .startTapped:
                return enqueueCommand(.start, state: &state)

            case .pauseTapped:
                return enqueueCommand(.pause, state: &state)

            case .verifyTapped:
                return enqueueCommand(.verify, state: &state)

            case .removeButtonTapped:
                state.removeConfirmation = .removeTorrent(name: state.name)
                return .none

            case .removeConfirmation(.presented(.deleteTorrentOnly)):
                state.removeConfirmation = nil
                return enqueueCommand(.remove(deleteData: false), state: &state)

            case .removeConfirmation(.presented(.deleteWithData)):
                state.removeConfirmation = nil
                return enqueueCommand(.remove(deleteData: true), state: &state)

            case .removeConfirmation(.presented(.cancel)):
                state.removeConfirmation = nil
                return .none

            case .removeConfirmation:
                return .none

            case .priorityChanged(let fileIndices, let priority):
                guard fileIndices.isEmpty == false else {
                    return .none
                }
                guard let mappedPriority = Self.filePriority(from: priority) else {
                    return .none
                }
                for index in fileIndices {
                    if var file = state.files[id: index] {
                        file.priority = mappedPriority.rawValue
                        state.files[id: index] = file
                    }
                }
                return enqueueCommand(
                    .priority(indices: fileIndices, priority: mappedPriority),
                    state: &state
                )

            case .toggleDownloadLimit(let isEnabled):
                state.downloadLimited = isEnabled
                return updateTransferSettings(
                    state: &state,
                    limit: .download(
                        .init(isEnabled: isEnabled, kilobytesPerSecond: state.downloadLimit)
                    )
                )

            case .toggleUploadLimit(let isEnabled):
                state.uploadLimited = isEnabled
                return updateTransferSettings(
                    state: &state,
                    limit: .upload(
                        .init(isEnabled: isEnabled, kilobytesPerSecond: state.uploadLimit)
                    )
                )

            case .downloadLimitChanged(let limit):
                let bounded = max(0, limit)
                state.downloadLimit = bounded
                guard state.downloadLimited else { return .none }
                return updateTransferSettings(
                    state: &state,
                    limit: .download(.init(isEnabled: true, kilobytesPerSecond: bounded))
                )

            case .uploadLimitChanged(let limit):
                let bounded = max(0, limit)
                state.uploadLimit = bounded
                guard state.uploadLimited else { return .none }
                return updateTransferSettings(
                    state: &state,
                    limit: .upload(.init(isEnabled: true, kilobytesPerSecond: bounded))
                )

            case .categoryChanged(let category):
                guard state.category != category else { return .none }
                guard state.connectionEnvironment != nil else {
                    state.alert = .connectionMissing()
                    return .none
                }
                state.category = category
                state.tags = TorrentCategory.tags(for: category)
                return updateCategory(state: &state)

            case .categoryUpdateResponse(.success):
                state.lastSyncedTags = state.tags
                state.pendingListSync = true
                return .send(.refreshRequested)

            case .categoryUpdateResponse(.failure(let message)):
                state.tags = state.lastSyncedTags
                state.category = TorrentCategory.category(from: state.lastSyncedTags)
                state.errorPresenter.banner = .init(
                    message: String(
                        format: L10n.tr("torrentDetail.error.updateCategory"),
                        message
                    ),
                    retry: nil
                )
                return .none

            case .commandDidFinish(let message):
                state.alert = .info(message: message)
                // Always trigger a refresh after any command so the tests (and UI)
                // observe a `.detailsResponse` with fresh data without user input.
                return .send(.refreshRequested)

            case .commandFailed(let message):
                state.alert = .error(message: message)
                return .none

            case .dismissError:
                state.errorPresenter.banner = nil
                return .none

            case .errorPresenter(.retryRequested(.reloadDetails)):
                return .send(.refreshRequested)

            case .errorPresenter(.retryRequested(.command(let command))):
                return enqueueCommand(command, state: &state)

            case .errorPresenter:
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
        .ifLet(\.$alert, action: \.alert)
        .ifLet(\.$removeConfirmation, action: \.removeConfirmation)
        Scope(state: \.errorPresenter, action: \.errorPresenter) {
            ErrorPresenter<ErrorRetry>()
        }
    }
}
