@preconcurrency import ComposableArchitecture
import Foundation

/// TCA Feature для отображения деталей торрента
/// Управляет состоянием деталей, файлов, трекеров и пиров
/// Поддерживает действия: Start, Stop, Remove, Verify, Set Priority
@ObservableState
struct TorrentDetailState: Equatable {
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

enum TorrentDetailAction: Equatable {
    /// Загрузить детали торрента с сервера
    case loadTorrentDetails

    /// Результат загрузки деталей
    case detailsLoaded(TransmissionResponse, Date)

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

@Reducer
struct TorrentDetailReducer {
    var body: some Reducer<TorrentDetailState, TorrentDetailAction> {
        Reduce { state, action in
            @Dependency(\.transmissionClient) var transmissionClient: TransmissionClientDependency
            @Dependency(\.date) var date: DateGenerator
            @Dependency(\.torrentDetailParser) var torrentDetailParser:
                TorrentDetailParserDependency

            switch action {
            case .loadTorrentDetails:
                state.isLoading = true
                state.errorMessage = nil
                let dateNow: Date = date.now

                return .run { [torrentId = state.torrentId] send in
                    do {
                        let response: TransmissionResponse =
                            try await transmissionClient.torrentGet(
                                [torrentId],
                                [
                                    "id", "name", "status", "percentDone", "totalSize",
                                    "downloadedEver", "uploadedEver", "eta",
                                    "rateDownload", "rateUpload", "uploadRatio",
                                    "downloadLimit", "downloadLimited",
                                    "uploadLimit", "uploadLimited",
                                    "peersConnected", "peersFrom",
                                    "downloadDir", "dateAdded",
                                    "files", "trackers", "trackerStats"
                                ]
                            )
                        await send(.detailsLoaded(response, dateNow))
                    } catch let error as APIError {
                        await send(.loadingFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.loadingFailed("Неизвестная ошибка: \(error)"))
                    }
                }

            case .detailsLoaded(let response, let timestamp):
                state.isLoading = false
                do {
                    let snapshot: TorrentDetailParsedSnapshot = try torrentDetailParser.parse(
                        response)
                    state.apply(snapshot)
                    state.errorMessage = nil
                    updateSpeedHistory(state: &state, timestamp: timestamp)
                } catch {
                    state.errorMessage = error.localizedDescription
                }
                return .none

            case .loadingFailed(let message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .startTorrent:
                return .run { [torrentId = state.torrentId] send in
                    do {
                        _ = try await transmissionClient.torrentStart([torrentId])
                        await send(.actionCompleted("Торрент запущен"))
                        // Перезагружаем детали
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при запуске: \(error)"))
                    }
                }

            case .stopTorrent:
                return .run { [torrentId = state.torrentId] send in
                    do {
                        _ = try await transmissionClient.torrentStop([torrentId])
                        await send(.actionCompleted("Торрент остановлен"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при остановке: \(error)"))
                    }
                }

            case .removeTorrent(let deleteData):
                return .run { [torrentId = state.torrentId] send in
                    do {
                        _ = try await transmissionClient.torrentRemove([torrentId], deleteData)
                        await send(.actionCompleted("Торрент удалён"))
                        // Сигнализируем о завершении родительскому редьюсеру
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при удалении: \(error)"))
                    }
                }

            case .verifyTorrent:
                return .run { [torrentId = state.torrentId] send in
                    do {
                        _ = try await transmissionClient.torrentVerify([torrentId])
                        await send(.actionCompleted("Проверка целостности запущена"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при проверке: \(error)"))
                    }
                }

            case .setPriority(let fileIndices, let priority):
                return .run { [torrentId = state.torrentId] send in
                    do {
                        var arguments: [String: AnyCodable] = ["ids": .array([.int(torrentId)])]

                        // Формируем аргументы для torrent-set
                        let priorityKey: String
                        switch priority {
                        case 0:
                            priorityKey = "priority-low"
                        case 1:
                            priorityKey = "priority-normal"
                        case 2:
                            priorityKey = "priority-high"
                        default:
                            priorityKey = "priority-normal"
                        }

                        arguments[priorityKey] = .array(fileIndices.map { .int($0) })

                        _ = try await transmissionClient.torrentSet(
                            [torrentId],
                            .object(arguments)
                        )
                        await send(.actionCompleted("Приоритет установлен"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при установке приоритета: \(error)"))
                    }
                }

            case .toggleDownloadLimit(let isEnabled):
                state.downloadLimited = isEnabled
                let limit: Int = state.downloadLimit
                let torrentId: Int = state.torrentId
                let payload: [String: AnyCodable] = [
                    "downloadLimited": .bool(isEnabled),
                    "downloadLimit": .int(limit)
                ]
                return .run { send in
                    do {
                        _ = try await transmissionClient.torrentSet([torrentId], .object(payload))
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при обновлении настроек: \(error)"))
                    }
                }

            case .toggleUploadLimit(let isEnabled):
                state.uploadLimited = isEnabled
                let limit: Int = state.uploadLimit
                let torrentId: Int = state.torrentId
                let payload: [String: AnyCodable] = [
                    "uploadLimited": .bool(isEnabled),
                    "uploadLimit": .int(limit)
                ]
                return .run { send in
                    do {
                        _ = try await transmissionClient.torrentSet([torrentId], .object(payload))
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при обновлении настроек: \(error)"))
                    }
                }

            case .updateDownloadLimit(let limit):
                let bounded: Int = max(0, limit)
                state.downloadLimit = bounded
                guard state.downloadLimited else {
                    return .none
                }
                let torrentId: Int = state.torrentId
                let payload: [String: AnyCodable] = [
                    "downloadLimited": .bool(true),
                    "downloadLimit": .int(bounded)
                ]
                return .run { send in
                    do {
                        _ = try await transmissionClient.torrentSet([torrentId], .object(payload))
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при обновлении настроек: \(error)"))
                    }
                }

            case .updateUploadLimit(let limit):
                let bounded: Int = max(0, limit)
                state.uploadLimit = bounded
                guard state.uploadLimited else {
                    return .none
                }
                let torrentId: Int = state.torrentId
                let payload: [String: AnyCodable] = [
                    "uploadLimited": .bool(true),
                    "uploadLimit": .int(bounded)
                ]
                return .run { send in
                    do {
                        _ = try await transmissionClient.torrentSet([torrentId], .object(payload))
                        await send(.actionCompleted("Настройки скоростей обновлены"))
                        await send(.loadTorrentDetails)
                    } catch let error as APIError {
                        await send(.actionFailed(error.userFriendlyMessage))
                    } catch {
                        await send(.actionFailed("Ошибка при обновлении настроек: \(error)"))
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
    fileprivate func updateSpeedHistory(state: inout TorrentDetailState, timestamp: Date) {
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
}

extension TorrentDetailState {
    private mutating func assign<Value>(
        _ value: Value?, to keyPath: WritableKeyPath<TorrentDetailState, Value>
    ) {
        guard let value else { return }
        self[keyPath: keyPath] = value
    }

    fileprivate mutating func apply(_ snapshot: TorrentDetailParsedSnapshot) {
        assign(snapshot.name, to: \.name)
        assign(snapshot.status, to: \.status)
        assign(snapshot.percentDone, to: \.percentDone)
        assign(snapshot.totalSize, to: \.totalSize)
        assign(snapshot.downloadedEver, to: \.downloadedEver)
        assign(snapshot.uploadedEver, to: \.uploadedEver)
        assign(snapshot.eta, to: \.eta)
        assign(snapshot.rateDownload, to: \.rateDownload)
        assign(snapshot.rateUpload, to: \.rateUpload)
        assign(snapshot.uploadRatio, to: \.uploadRatio)
        assign(snapshot.downloadLimit, to: \.downloadLimit)
        assign(snapshot.downloadLimited, to: \.downloadLimited)
        assign(snapshot.uploadLimit, to: \.uploadLimit)
        assign(snapshot.uploadLimited, to: \.uploadLimited)
        assign(snapshot.peersConnected, to: \.peersConnected)
        assign(snapshot.downloadDir, to: \.downloadDir)
        assign(snapshot.dateAdded, to: \.dateAdded)
        self.peersFrom = snapshot.peersFrom
        self.files = snapshot.files
        self.trackers = snapshot.trackers
        self.trackerStats = snapshot.trackerStats
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
        case .versionUnsupported(let version):
            return "Версия Transmission не поддерживается (\(version))"
        case .decodingFailed:
            return "Ошибка парсирования ответа"
        case .unknown(let details):
            return "Ошибка: \(details)"
        }
    }
}
