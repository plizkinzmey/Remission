@preconcurrency import ComposableArchitecture
import Foundation

@Reducer
struct TorrentDetailReducer {
    /// TCA Feature для отображения деталей торрента
    /// Управляет состоянием деталей, файлов, трекеров и пиров
    /// Поддерживает действия: Start, Stop, Remove, Verify, Set Priority
    @ObservableState
    struct State: Equatable {
        /// ID торрента
        var torrentId: Int

        /// Основная информация о торренте
        var name: String = ""
        var status: Int = 0  // 0-7 статусы Transmission
        var percentDone: Double = 0.0  // 0.0-1.0
        var totalSize: Int = 0
        var downloadedEver: Int = 0
        var uploadedEver: Int = 0
        var eta: Int = 0  // секунды, -1 если нет

        /// Статистика скоростей
        var rateDownload: Int = 0  // bytes/sec
        var rateUpload: Int = 0  // bytes/sec
        var uploadRatio: Double = 0.0
        var downloadLimit: Int = 0  // KB/s
        var downloadLimited: Bool = false
        var uploadLimit: Int = 0  // KB/s
        var uploadLimited: Bool = false
        var speedHistory: [SpeedSample] = []

        /// Пиры и подключения
        var peersConnected: Int = 0
        var peersFrom: [PeerSource] = []  // источники пиров

        /// Пути и каталоги
        var downloadDir: String = ""
        var dateAdded: Int = 0  // Unix timestamp

        /// Файлы торрента
        var files: [TorrentFile] = []

        /// Трекеры и их статистика
        var trackers: [TorrentTracker] = []
        var trackerStats: [TrackerStat] = []

        /// UI состояние
        var isLoading: Bool = false
        var errorMessage: String?
    }

    private enum CancelID: Hashable {
        case loadTorrentDetails
    }

    enum Action: Equatable {
        /// Загрузить детали торрента с сервера
        case loadTorrentDetails

        /// Результат загрузки деталей
        case detailsLoaded(Torrent, Date)

        /// Ошибка при загрузке
        case loadingFailed(String)

        /// Действия управления
        case startTorrent
        case stopTorrent
        case removeTorrent(deleteData: Bool)
        case verifyTorrent

        /// Установка приоритета
        case setPriority(fileIndices: [Int], priority: Int)

        /// Управление лимитами
        case toggleDownloadLimit(Bool)
        case toggleUploadLimit(Bool)
        case updateDownloadLimit(Int)
        case updateUploadLimit(Int)

        /// Результаты действий
        case actionCompleted(String)
        case actionFailed(String)

        /// Очистка ошибки
        case clearError
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            @Dependency(\.torrentRepository) var torrentRepository: TorrentRepository
            @Dependency(\.date) var date: DateGenerator

            switch action {
            case .loadTorrentDetails:
                state.isLoading = true
                state.errorMessage = nil
                let dateNow: Date = date.now
                let repository: TorrentRepository = torrentRepository
                let torrentIdentifier = Torrent.Identifier(rawValue: state.torrentId)

                return .run { [torrentIdentifier, dateNow, repository] send in
                    do {
                        let torrent: Torrent = try await repository.fetchDetails(torrentIdentifier)
                        await send(.detailsLoaded(torrent, dateNow))
                    } catch is CancellationError {
                        return
                    } catch {
                        await send(.loadingFailed(Self.errorMessage(from: error)))
                    }
                }
                .cancellable(id: CancelID.loadTorrentDetails, cancelInFlight: true)

            case .detailsLoaded(let torrent, let timestamp):
                state.isLoading = false
                state.apply(torrent)
                state.errorMessage = nil
                updateSpeedHistory(state: &state, timestamp: timestamp)
                return .none

            case .loadingFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .startTorrent:
                let repository: TorrentRepository = torrentRepository
                let identifiers: [Torrent.Identifier] = [
                    Torrent.Identifier(rawValue: state.torrentId)
                ]
                return .run { [identifiers, repository] send in
                    do {
                        try await repository.start(identifiers)
                        await send(.actionCompleted("Торрент запущен"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .stopTorrent:
                let repository: TorrentRepository = torrentRepository
                let identifiers: [Torrent.Identifier] = [
                    Torrent.Identifier(rawValue: state.torrentId)
                ]
                return .run { [identifiers, repository] send in
                    do {
                        try await repository.stop(identifiers)
                        await send(.actionCompleted("Торрент остановлен"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .removeTorrent(let deleteData):
                let repository: TorrentRepository = torrentRepository
                let identifiers: [Torrent.Identifier] = [
                    Torrent.Identifier(rawValue: state.torrentId)
                ]
                return .run { [identifiers, repository, deleteData] send in
                    do {
                        try await repository.remove(identifiers, deleteLocalData: deleteData)
                        await send(.actionCompleted("Торрент удалён"))
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .verifyTorrent:
                let repository: TorrentRepository = torrentRepository
                let identifiers: [Torrent.Identifier] = [
                    Torrent.Identifier(rawValue: state.torrentId)
                ]
                return .run { [identifiers, repository] send in
                    do {
                        try await repository.verify(identifiers)
                        await send(.actionCompleted("Проверка целостности запущена"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .setPriority(let fileIndices, let priority):
                let repository: TorrentRepository = torrentRepository
                let torrentIdentifier = Torrent.Identifier(rawValue: state.torrentId)
                let mappedPriority: TorrentRepository.FilePriority? = {
                    switch priority {
                    case 0: return .low
                    case 1: return .normal
                    case 2: return .high
                    default: return nil
                    }
                }()
                let updates: [TorrentRepository.FileSelectionUpdate] = fileIndices.map {
                    TorrentRepository.FileSelectionUpdate(
                        fileIndex: $0,
                        priority: mappedPriority
                    )
                }
                return .run { [torrentIdentifier, updates, repository] send in
                    do {
                        try await repository.updateFileSelection(updates, in: torrentIdentifier)
                        await send(.actionCompleted("Приоритет установлен"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .toggleDownloadLimit(let isEnabled):
                state.downloadLimited = isEnabled
                let repository: TorrentRepository = torrentRepository
                let torrentIdentifier = Torrent.Identifier(rawValue: state.torrentId)
                let transferLimit = TorrentRepository.TransferLimit(
                    isEnabled: isEnabled,
                    kilobytesPerSecond: state.downloadLimit
                )
                return .run { [repository, torrentIdentifier, transferLimit] send in
                    do {
                        try await repository.updateTransferSettings(
                            .init(downloadLimit: transferLimit),
                            for: [torrentIdentifier]
                        )
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .toggleUploadLimit(let isEnabled):
                state.uploadLimited = isEnabled
                let repository: TorrentRepository = torrentRepository
                let torrentIdentifier = Torrent.Identifier(rawValue: state.torrentId)
                let transferLimit = TorrentRepository.TransferLimit(
                    isEnabled: isEnabled,
                    kilobytesPerSecond: state.uploadLimit
                )
                return .run { [repository, torrentIdentifier, transferLimit] send in
                    do {
                        try await repository.updateTransferSettings(
                            .init(uploadLimit: transferLimit),
                            for: [torrentIdentifier]
                        )
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .updateDownloadLimit(let limit):
                let bounded: Int = max(0, limit)
                state.downloadLimit = bounded
                guard state.downloadLimited else {
                    return .none
                }
                let repository: TorrentRepository = torrentRepository
                let torrentIdentifier = Torrent.Identifier(rawValue: state.torrentId)
                let transferLimit = TorrentRepository.TransferLimit(
                    isEnabled: true,
                    kilobytesPerSecond: bounded
                )
                return .run { [repository, torrentIdentifier, transferLimit] send in
                    do {
                        try await repository.updateTransferSettings(
                            .init(downloadLimit: transferLimit),
                            for: [torrentIdentifier]
                        )
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .updateUploadLimit(let limit):
                let bounded: Int = max(0, limit)
                state.uploadLimit = bounded
                guard state.uploadLimited else {
                    return .none
                }
                let repository: TorrentRepository = torrentRepository
                let torrentIdentifier = Torrent.Identifier(rawValue: state.torrentId)
                let transferLimit = TorrentRepository.TransferLimit(
                    isEnabled: true,
                    kilobytesPerSecond: bounded
                )
                return .run { [repository, torrentIdentifier, transferLimit] send in
                    do {
                        try await repository.updateTransferSettings(
                            .init(uploadLimit: transferLimit),
                            for: [torrentIdentifier]
                        )
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch {
                        await send(.actionFailed(Self.errorMessage(from: error)))
                    }
                }

            case .actionCompleted:
                return .none

            case .actionFailed:
                return .none

            case .clearError:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

// MARK: - Reducer helpers

extension TorrentDetailReducer {
    fileprivate func updateSpeedHistory(state: inout State, timestamp: Date) {
        let sample: SpeedSample = SpeedSample(
            timestamp: timestamp,
            downloadRate: state.rateDownload,
            uploadRate: state.rateUpload
        )
        state.speedHistory.append(sample)
        if state.speedHistory.count > 20 {
            state.speedHistory.removeFirst(state.speedHistory.count - 20)
        }
    }

    fileprivate static func errorMessage(from error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.userFriendlyMessage
        }
        return error.localizedDescription
    }
}

extension TorrentDetailReducer.State {
    fileprivate mutating func apply(_ torrent: Torrent) {
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
        peersFrom = torrent.summary.peers.sources

        if let details = torrent.details {
            downloadDir = details.downloadDirectory
            if let addedDate = details.addedDate {
                dateAdded = Int(addedDate.timeIntervalSince1970)
            }
            files = details.files
            trackers = details.trackers
            trackerStats = details.trackerStats
        } else {
            files = []
            trackers = []
            trackerStats = []
        }
    }
}

// MARK: - Extension for APIError
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
