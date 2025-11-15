import ComposableArchitecture
import Foundation

// swiftlint:disable type_body_length

@Reducer
struct TorrentDetailReducer {
    enum Action: Equatable {
        case task
        case teardown
        case refreshRequested
        case detailsResponse(TaskResult<DetailsResponse>)
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
        case commandDidFinish(String)
        case commandFailed(String)
        case dismissError
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
        case torrentRemoved(Torrent.Identifier)
    }

    @Dependency(\.dateProvider) var dateProvider

    private enum FetchTrigger {
        case initial
        case manual
    }

    private enum CancelID: Hashable {
        case loadTorrentDetails
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
                return .cancel(id: CancelID.loadTorrentDetails)

            case .detailsResponse(.success(let response)):
                state.isLoading = false
                state.errorMessage = nil
                state.apply(response.torrent)
                state.speedHistory.append(
                    timestamp: response.timestamp,
                    downloadRate: state.rateDownload,
                    uploadRate: state.rateUpload
                )
                return .none

            case .detailsResponse(.failure(let error)):
                state.isLoading = false
                let message = Self.describe(error)
                state.errorMessage = message
                return .none

            case .startTapped:
                return runCommand(
                    state: &state,
                    successAction: .commandDidFinish("Торрент запущен")
                ) { repository, torrentID in
                    try await repository.start([torrentID])
                }

            case .pauseTapped:
                return runCommand(
                    state: &state,
                    successAction: .commandDidFinish("Торрент остановлен")
                ) { repository, torrentID in
                    try await repository.stop([torrentID])
                }

            case .verifyTapped:
                return runCommand(
                    state: &state,
                    successAction: .commandDidFinish("Проверка запущена")
                ) { repository, torrentID in
                    try await repository.verify([torrentID])
                }

            case .removeButtonTapped:
                state.removeConfirmation = .removeTorrent(name: state.name)
                return .none

            case .removeConfirmation(.presented(.deleteTorrentOnly)):
                state.removeConfirmation = nil
                return runCommand(
                    state: &state,
                    successAction: .delegate(.torrentRemoved(state.torrentID))
                ) { repository, torrentID in
                    try await repository.remove([torrentID], deleteLocalData: false)
                }

            case .removeConfirmation(.presented(.deleteWithData)):
                state.removeConfirmation = nil
                return runCommand(
                    state: &state,
                    successAction: .delegate(.torrentRemoved(state.torrentID))
                ) { repository, torrentID in
                    try await repository.remove([torrentID], deleteLocalData: true)
                }

            case .removeConfirmation(.presented(.cancel)):
                state.removeConfirmation = nil
                return .none

            case .removeConfirmation:
                return .none

            case .priorityChanged(let fileIndices, let priority):
                guard let environment = state.connectionEnvironment else {
                    state.alert = .connectionMissing()
                    return .none
                }
                guard let mappedPriority = Self.filePriority(from: priority) else {
                    return .none
                }
                let torrentID = state.torrentID
                return .run { send in
                    let result = await TaskResult {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.torrentRepository) var repository: TorrentRepository
                            let updates = fileIndices.map {
                                TorrentRepository.FileSelectionUpdate(
                                    fileIndex: $0,
                                    priority: mappedPriority
                                )
                            }
                            try await repository.updateFileSelection(updates, in: torrentID)
                        }
                    }

                    switch result {
                    case .success:
                        await send(.commandDidFinish("Приоритет обновлён"))
                    case .failure(let error):
                        await send(.commandFailed(Self.describe(error)))
                    }
                }

            case .toggleDownloadLimit(let isEnabled):
                state.downloadLimited = isEnabled
                guard isEnabled else {
                    return .none
                }
                return updateTransferSettings(
                    state: &state,
                    limit: .download(
                        .init(isEnabled: true, kilobytesPerSecond: state.downloadLimit)
                    )
                )

            case .toggleUploadLimit(let isEnabled):
                state.uploadLimited = isEnabled
                guard isEnabled else {
                    return .none
                }
                return updateTransferSettings(
                    state: &state,
                    limit: .upload(
                        .init(isEnabled: true, kilobytesPerSecond: state.uploadLimit)
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

            case .commandDidFinish(let message):
                state.alert = .info(message: message)
                return .send(.refreshRequested)

            case .commandFailed(let message):
                state.alert = .error(message: message)
                return .none

            case .dismissError:
                state.errorMessage = nil
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
    }

    private func loadDetails(
        state: inout State,
        trigger: FetchTrigger
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.isLoading = false
            state.errorMessage = "Нет подключения к серверу"
            return .none
        }

        switch trigger {
        case .initial:
            state.isLoading = true
        case .manual:
            state.isLoading = true
        }

        state.errorMessage = nil
        let torrentID = state.torrentID
        return .run { send in
            await send(
                .detailsResponse(
                    TaskResult {
                        try await withDependencies {
                            environment.apply(to: &$0)
                        } operation: {
                            @Dependency(\.torrentRepository) var repository: TorrentRepository
                            let torrent = try await repository.fetchDetails(torrentID)
                            return DetailsResponse(
                                torrent: torrent,
                                timestamp: dateProvider.now()
                            )
                        }
                    }
                )
            )
        }
        .cancellable(id: CancelID.loadTorrentDetails, cancelInFlight: true)
    }

    private func runCommand(
        state: inout State,
        successAction: Action,
        operation: @escaping @Sendable (TorrentRepository, Torrent.Identifier) async throws -> Void
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.alert = .connectionMissing()
            return .none
        }

        let torrentID = state.torrentID
        return .run { send in
            let result = await TaskResult {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    try await operation(repository, torrentID)
                    return
                }
            }

            switch result {
            case .success:
                await send(successAction)
            case .failure(let error):
                await send(.commandFailed(Self.describe(error)))
            }
        }
    }

    private enum TransferLimitUpdate {
        case download(TorrentRepository.TransferLimit)
        case upload(TorrentRepository.TransferLimit)
    }

    private func updateTransferSettings(
        state: inout State,
        limit: TransferLimitUpdate
    ) -> Effect<Action> {
        guard let environment = state.connectionEnvironment else {
            state.alert = .connectionMissing()
            return .none
        }

        let torrentID = state.torrentID
        return .run { send in
            let result = await TaskResult {
                try await withDependencies {
                    environment.apply(to: &$0)
                } operation: {
                    @Dependency(\.torrentRepository) var repository: TorrentRepository
                    switch limit {
                    case .download(let transfer):
                        try await repository.updateTransferSettings(
                            .init(downloadLimit: transfer),
                            for: [torrentID]
                        )
                    case .upload(let transfer):
                        try await repository.updateTransferSettings(
                            .init(uploadLimit: transfer),
                            for: [torrentID]
                        )
                    }
                }
            }

            switch result {
            case .success:
                await send(.commandDidFinish("Настройки скоростей обновлены"))
            case .failure(let error):
                await send(.commandFailed(Self.describe(error)))
            }
        }
    }

    private static func filePriority(from priority: Int) -> TorrentRepository.FilePriority? {
        switch priority {
        case 0: return .low
        case 1: return .normal
        case 2: return .high
        default: return nil
        }
    }

    private static func describe(_ error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userFriendlyMessage
        }
        if let parserError = error as? TorrentDetailParserError {
            return parserError.localizedDescription
        }
        return error.localizedDescription
    }
}

// MARK: - Reducer helpers

extension TorrentDetailReducer.State {
    mutating func apply(_ torrent: Torrent) {
        torrentID = torrent.id
        name = torrent.name
        status = torrent.status.rawValue
        percentDone = torrent.summary.progress.percentDone
        totalSize = torrent.summary.progress.totalSize
        downloadedEver = torrent.summary.progress.downloadedEver
        uploadedEver = torrent.summary.progress.uploadedEver
        uploadRatio = torrent.summary.progress.uploadRatio
        eta = torrent.summary.progress.etaSeconds

        rateDownload = torrent.summary.transfer.downloadRate
        rateUpload = torrent.summary.transfer.uploadRate
        downloadLimit = torrent.summary.transfer.downloadLimit.kilobytesPerSecond
        downloadLimited = torrent.summary.transfer.downloadLimit.isEnabled
        uploadLimit = torrent.summary.transfer.uploadLimit.kilobytesPerSecond
        uploadLimited = torrent.summary.transfer.uploadLimit.isEnabled

        peersConnected = torrent.summary.peers.connected
        peers = IdentifiedArray(uniqueElements: torrent.summary.peers.sources)

        if let details = torrent.details {
            downloadDir = details.downloadDirectory
            if let addedDate = details.addedDate {
                dateAdded = Int(addedDate.timeIntervalSince1970)
            }
            files = IdentifiedArray(uniqueElements: details.files)
            trackers = IdentifiedArray(uniqueElements: details.trackers)
            trackerStats = IdentifiedArray(uniqueElements: details.trackerStats)
        } else {
            files = []
            trackers = []
            trackerStats = []
        }
    }
}

extension AlertState where Action == TorrentDetailReducer.AlertAction {
    static func info(message: String) -> AlertState {
        AlertState {
            TextState("Готово")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            TextState(message)
        }
    }

    static func error(message: String) -> AlertState {
        AlertState {
            TextState("Ошибка")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("Понятно")
            }
        } message: {
            TextState(message)
        }
    }

    static func connectionMissing() -> AlertState {
        .error(message: "Нет подключения к серверу")
    }
}

extension ConfirmationDialogState
where Action == TorrentDetailReducer.RemoveConfirmationAction {
    static func removeTorrent(name: String) -> ConfirmationDialogState {
        ConfirmationDialogState {
            TextState("Удалить торрент «\(name.isEmpty ? "Без названия" : name)»?")
        } actions: {
            ButtonState(role: .destructive, action: .deleteTorrentOnly) {
                TextState("Удалить торрент")
            }
            ButtonState(role: .destructive, action: .deleteWithData) {
                TextState("Удалить с данными")
            }
            ButtonState(role: .cancel, action: .cancel) {
                TextState("Отмена")
            }
        }
    }
}

extension APIError {
    var userFriendlyMessage: String {
        switch self {
        case .networkUnavailable:
            return "Сеть недоступна"
        case .unauthorized:
            return "Ошибка аутентификации"
        case .sessionConflict:
            return "Конфликт сессии"
        case .tlsTrustDeclined:
            return "Подключение отклонено: сертификат не доверен"
        case .tlsEvaluationFailed(let details):
            return "Ошибка проверки сертификата: \(details)"
        case .versionUnsupported(let version):
            return "Версия Transmission не поддерживается (\(version))"
        case .decodingFailed:
            return "Ошибка парсирования ответа"
        case .unknown(let details):
            return "Ошибка: \(details)"
        }
    }
}

// swiftlint:enable type_body_length
