import ComposableArchitecture
import Foundation

@Reducer
struct TorrentDetailReducer {
    // MARK: - Action
    enum AlertAction: Equatable { case dismiss }
    enum RemoveConfirmationAction: Equatable { case deleteTorrentOnly, deleteWithData, cancel }

    enum Action: Equatable {
        case task
        case teardown
        case refreshRequested
        case detailsResponse(TaskResult<DetailsResponse>)

        // Sub-reducers
        case files(TorrentFilesReducer.Action)
        case peers(TorrentPeersReducer.Action)
        case trackers(TorrentTrackersReducer.Action)
        case stats(TorrentStatsReducer.Action)
        case commands(TorrentCommandsReducer.Action)
        case transferLimits(TorrentTransferLimitsReducer.Action)
        case category(TorrentCategoryReducer.Action)

        // Commands (UI)
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

        // Responses
        case commandResponse(TorrentCommandsReducer.CommandResult)
        case commandDidFinish(String)
        case commandFailed(String)
        case dismissError
        case categoryUpdateResponse(CategoryUpdateResult)

        // UI
        case errorPresenter(ErrorPresenter<ErrorRetry>.Action)
        case alert(PresentationAction<AlertAction>)
        case delegate(Delegate)
    }

    enum ErrorRetry: Equatable {
        case reloadDetails
        case command(CommandKind)
    }

    @Dependency(\.dateProvider) var dateProvider

    enum FetchTrigger { case initial, manual }
    enum CancelID: Hashable { case loadTorrentDetails, commandExecution }
    // MARK: - Reducer
    var body: some ReducerOf<Self> {
        CombineReducers {
            // Sub-reducers
            Scope(state: \.files, action: \.files) { TorrentFilesReducer() }
            Scope(state: \.peers, action: \.peers) { TorrentPeersReducer() }
            Scope(state: \.trackers, action: \.trackers) { TorrentTrackersReducer() }
            Scope(state: \.stats, action: \.stats) { TorrentStatsReducer() }
            Scope(state: \.commands, action: \.commands) { TorrentCommandsReducer() }
            Scope(state: \.transferLimits, action: \.transferLimits) {
                TorrentTransferLimitsReducer()
            }
            Scope(state: \.categoryState, action: \.category) { TorrentCategoryReducer() }

            // Main coordinator
            Reduce { (state: inout State, action: Action) -> Effect<Action> in
                switch action {
                case .task:
                    return loadDetails(state: &state, trigger: .initial)

                case .refreshRequested:
                    return loadDetails(state: &state, trigger: .manual)

                case .teardown:
                    state.isLoading = false
                    state.commands.pendingCommands.removeAll()
                    state.commands.activeCommand = nil
                    state.pendingStatusChange = nil
                    state.pendingListSync = false
                    return .merge(
                        .cancel(id: CancelID.loadTorrentDetails),
                        .cancel(id: CancelID.commandExecution)
                    )

                case .detailsResponse(.success(let response)):
                    state.isLoading = false
                    state.errorPresenter.banner = nil
                    state.apply(response.torrent)
                    state.stats.speedHistory.append(
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
                    if error is CancellationError {
                        state.pendingListSync = false
                        return .none
                    }
                    let message = error.userFacingMessage
                    state.errorPresenter.banner = .init(message: message, retry: .reloadDetails)
                    state.pendingListSync = false
                    return .none

                // Commands from UI
                case .startTapped:
                    return .send(.commands(.enqueueCommand(.start)))
                case .pauseTapped:
                    return .send(.commands(.enqueueCommand(.pause)))
                case .verifyTapped:
                    return .send(.commands(.enqueueCommand(.verify)))
                case .removeButtonTapped:
                    state.removeConfirmation = ConfirmationDialogState<
                        TorrentDetailReducer.RemoveConfirmationAction
                    >.removeTorrent(name: state.name)
                    return .none
                case .removeConfirmation(.presented(.deleteTorrentOnly)):
                    state.removeConfirmation = nil
                    return .send(.delegate(.removeRequested(state.torrentID, deleteData: false)))
                case .removeConfirmation(.presented(.deleteWithData)):
                    state.removeConfirmation = nil
                    return .send(.delegate(.removeRequested(state.torrentID, deleteData: true)))
                case .removeConfirmation(.presented(.cancel)), .removeConfirmation:
                    state.removeConfirmation = nil
                    return .none

                case .priorityChanged(let fileIndices, let priority):
                    return .send(
                        .files(.priorityChanged(fileIndices: fileIndices, priority: priority)))

                case .toggleDownloadLimit(let isEnabled):
                    return .send(.transferLimits(.toggleDownloadLimit(isEnabled)))
                case .toggleUploadLimit(let isEnabled):
                    return .send(.transferLimits(.toggleUploadLimit(isEnabled)))
                case .downloadLimitChanged(let limit):
                    return .send(.transferLimits(.downloadLimitChanged(limit)))
                case .uploadLimitChanged(let limit):
                    return .send(.transferLimits(.uploadLimitChanged(limit)))

                case .categoryChanged(let category):
                    return .send(.category(.categoryChanged(category)))

                // Sub-reducer delegate handling
                case .files(.delegate(.priorityChanged(let fileIndices, let priority))):
                    return enqueueCommand(
                        .priority(indices: fileIndices, priority: priority),
                        state: &state
                    )

                case .peers(.delegate(.refreshPeers)):
                    return .send(.refreshRequested)

                case .trackers(.delegate(.refreshTrackers)):
                    return .send(.refreshRequested)

                case .commands(.delegate(.executeCommand(let command))):
                    // Set initial status for status change tracking
                    if Self.shouldWaitForStatusChange(command) {
                        state.pendingStatusChange = .init(
                            command: command, initialStatus: state.status)
                    }
                    return execute(command: command, state: &state)

                case .commands(.delegate(.commandSuccess(let command))):
                    state.commands.activeCommand = nil
                    if Self.shouldSyncList(after: command) { state.pendingListSync = true }
                    let torrentID = state.torrentID
                    return .merge(
                        commandSuccessEffect(for: command, torrentID: torrentID),
                        .send(.commands(.startNextCommand))
                    )

                case .commands(.delegate(.commandFailed(_, let message))):
                    state.commands.activeCommand = nil
                    state.pendingStatusChange = nil
                    return .merge(
                        .send(.commandFailed(message)), .send(.commands(.startNextCommand)))

                case .transferLimits(.delegate(.updateTransferLimit(let limit))):
                    return updateTransferSettings(state: &state, limit: limit)

                case .category(.delegate(.updateCategory(let category))):
                    return updateCategory(state: &state, category: category)
                case .category(.delegate(.categorySynced)):
                    state.categoryState.lastSyncedTags = state.categoryState.tags
                    state.pendingListSync = true
                    return .send(.refreshRequested)
                case .category(.delegate(.categoryUpdateFailed(let message))):
                    state.categoryState.tags = state.categoryState.lastSyncedTags
                    state.categoryState.category = TorrentCategory.category(
                        from: state.categoryState.lastSyncedTags)
                    state.errorPresenter.banner = .init(
                        message: String(
                            format: L10n.tr("torrentDetail.error.updateCategory"), message),
                        retry: nil
                    )
                    return .none

                // Command responses from execution
                case .commandResponse(.success(let command)):
                    return .send(.commands(.commandResponse(.success(command))))
                case .commandResponse(.failure(let command, let message)):
                    return .send(.commands(.commandResponse(.failure(command, message))))

                // Other
                case .commandDidFinish(let message):
                    state.alert = AlertState<TorrentDetailReducer.AlertAction>.info(
                        message: message)
                    return .send(.refreshRequested)
                case .commandFailed(let message):
                    state.alert = AlertState<TorrentDetailReducer.AlertAction>.error(
                        message: message)
                    return .none
                case .dismissError:
                    state.errorPresenter.banner = nil
                    return .none
                case .categoryUpdateResponse(.success):
                    state.categoryState.lastSyncedTags = state.categoryState.tags
                    state.pendingListSync = true
                    return .send(.refreshRequested)
                case .categoryUpdateResponse(.failure(let message)):
                    state.categoryState.tags = state.categoryState.lastSyncedTags
                    state.categoryState.category = TorrentCategory.category(
                        from: state.categoryState.lastSyncedTags)
                    state.errorPresenter.banner = .init(
                        message: String(
                            format: L10n.tr("torrentDetail.error.updateCategory"), message),
                        retry: nil
                    )
                    return .none

                case .errorPresenter(.retryRequested(.reloadDetails)):
                    return .send(.refreshRequested)
                case .errorPresenter(.retryRequested(.command(let command))):
                    return .send(.commands(.enqueueCommand(command)))
                case .errorPresenter:
                    return .none

                case .alert(.presented(.dismiss)):
                    state.alert = nil
                    return .none
                case .alert:
                    return .none

                case .files, .peers, .trackers, .stats, .commands, .transferLimits, .category:
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

}
