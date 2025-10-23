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
                // Парсируем ответ и обновляем состояние
                parseAndUpdateState(&state, from: response, now: timestamp)
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
    fileprivate func parseAndUpdateState(
        _ state: inout TorrentDetailState,
        from response: TransmissionResponse,
        now: Date
    ) {
        guard let torrentDict = extractTorrentDictionary(from: response) else {
            state.errorMessage = "Ошибка парсирования ответа сервера"
            return
        }

        parsePrimaryFields(into: &state, from: torrentDict)
        parseSpeedAndLimits(into: &state, from: torrentDict)
        parsePeers(into: &state, from: torrentDict)
        parseFiles(into: &state, from: torrentDict)
        parseTrackers(into: &state, from: torrentDict)
        updateSpeedHistory(state: &state, timestamp: now)
    }

    fileprivate func extractTorrentDictionary(
        from response: TransmissionResponse
    ) -> [String: AnyCodable]? {
        guard let arguments = response.arguments,
            case .object(let dict) = arguments,
            let torrentsData = dict["torrents"],
            case .array(let torrentsArray) = torrentsData,
            let torrentObj = torrentsArray.first,
            case .object(let torrentDict) = torrentObj
        else {
            return nil
        }

        return torrentDict
    }

    fileprivate func parsePrimaryFields(
        into state: inout TorrentDetailState,
        from dict: [String: AnyCodable]
    ) {
        if let name = stringValue(for: "name", in: dict) {
            state.name = name
        }

        if let status = intValue(for: "status", in: dict) {
            state.status = status
        }

        if let percent = dict["percentDone"] {
            switch percent {
            case .double(let value):
                state.percentDone = value
            case .int(let value):
                state.percentDone = Double(value) / 100.0
            default:
                break
            }
        }

        state.totalSize = intValue(for: "totalSize", in: dict) ?? state.totalSize
        state.downloadedEver = intValue(for: "downloadedEver", in: dict) ?? state.downloadedEver
        state.uploadedEver = intValue(for: "uploadedEver", in: dict) ?? state.uploadedEver
        state.eta = intValue(for: "eta", in: dict) ?? state.eta
        state.downloadDir = stringValue(for: "downloadDir", in: dict) ?? state.downloadDir
        state.dateAdded = intValue(for: "dateAdded", in: dict) ?? state.dateAdded
    }

    fileprivate func parseSpeedAndLimits(
        into state: inout TorrentDetailState,
        from dict: [String: AnyCodable]
    ) {
        state.rateDownload = intValue(for: "rateDownload", in: dict) ?? state.rateDownload
        state.rateUpload = intValue(for: "rateUpload", in: dict) ?? state.rateUpload
        state.uploadRatio = doubleValue(for: "uploadRatio", in: dict) ?? state.uploadRatio
        state.peersConnected = intValue(for: "peersConnected", in: dict) ?? state.peersConnected

        state.downloadLimit = intValue(for: "downloadLimit", in: dict) ?? state.downloadLimit
        state.downloadLimited = boolValue(for: "downloadLimited", in: dict) ?? state.downloadLimited
        state.uploadLimit = intValue(for: "uploadLimit", in: dict) ?? state.uploadLimit
        state.uploadLimited = boolValue(for: "uploadLimited", in: dict) ?? state.uploadLimited
    }

    fileprivate func parsePeers(
        into state: inout TorrentDetailState, from dict: [String: AnyCodable]
    ) {
        guard let peersValue = dict["peersFrom"], case .object(let peersDict) = peersValue else {
            state.peersFrom = []
            return
        }

        state.peersFrom = peersDict.compactMap { key, value in
            if case .int(let count) = value {
                return PeerSource(name: key, count: count)
            }
            return nil
        }
        .sorted { lhs, rhs in lhs.count > rhs.count }
    }

    fileprivate func parseFiles(
        into state: inout TorrentDetailState, from dict: [String: AnyCodable]
    ) {
        guard let filesValue = dict["files"], case .array(let filesArray) = filesValue else {
            state.files = []
            return
        }

        state.files = filesArray.enumerated().compactMap { index, fileData in
            guard case .object(let fileDict) = fileData,
                let name = stringValue(for: "name", in: fileDict),
                let length = intValue(for: "length", in: fileDict),
                let completed = intValue(for: "bytesCompleted", in: fileDict)
            else {
                return nil
            }

            let priority: Int = intValue(for: "priority", in: fileDict) ?? 1

            return TorrentFile(
                index: index,
                name: name,
                length: length,
                bytesCompleted: completed,
                priority: priority
            )
        }
    }

    fileprivate func parseTrackers(
        into state: inout TorrentDetailState, from dict: [String: AnyCodable]
    ) {
        state.trackers = trackerList(from: dict)
        state.trackerStats = trackerStats(from: dict)
    }

    fileprivate func trackerList(from dict: [String: AnyCodable]) -> [TorrentTracker] {
        guard let trackersValue = dict["trackers"], case .array(let trackersArray) = trackersValue
        else {
            return []
        }

        return trackersArray.enumerated().compactMap { index, trackerData in
            guard case .object(let trackerDict) = trackerData,
                let announce = stringValue(for: "announce", in: trackerDict)
            else {
                return nil
            }

            let tier: Int = intValue(for: "tier", in: trackerDict) ?? 0
            return TorrentTracker(index: index, announce: announce, tier: tier)
        }
    }

    fileprivate func trackerStats(from dict: [String: AnyCodable]) -> [TrackerStat] {
        guard let statsValue = dict["trackerStats"], case .array(let statsArray) = statsValue else {
            return []
        }

        return statsArray.compactMap { statData in
            guard case .object(let statDict) = statData else {
                return nil
            }

            let trackerId: Int =
                intValue(for: "id", in: statDict)
                ?? intValue(for: "trackerId", in: statDict)
                ?? 0

            let announceResult: String = stringValue(for: "lastAnnounceResult", in: statDict) ?? ""
            let downloadCount: Int = intValue(for: "downloadCount", in: statDict) ?? 0
            let leecherCount: Int = intValue(for: "leecherCount", in: statDict) ?? 0
            let seederCount: Int = intValue(for: "seederCount", in: statDict) ?? 0

            return TrackerStat(
                trackerId: trackerId,
                lastAnnounceResult: announceResult,
                downloadCount: downloadCount,
                leecherCount: leecherCount,
                seederCount: seederCount
            )
        }
    }

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

    fileprivate func intValue(for key: String, in dict: [String: AnyCodable]) -> Int? {
        guard let value = dict[key] else { return nil }
        if case .int(let intValue) = value {
            return intValue
        }
        return nil
    }

    fileprivate func doubleValue(for key: String, in dict: [String: AnyCodable]) -> Double? {
        guard let value = dict[key] else { return nil }
        if case .double(let doubleValue) = value {
            return doubleValue
        }
        if case .int(let intValue) = value {
            return Double(intValue)
        }
        return nil
    }

    fileprivate func boolValue(for key: String, in dict: [String: AnyCodable]) -> Bool? {
        guard let value = dict[key] else { return nil }
        if case .bool(let boolValue) = value {
            return boolValue
        }
        return nil
    }

    fileprivate func stringValue(for key: String, in dict: [String: AnyCodable]) -> String? {
        guard let value = dict[key] else { return nil }
        if case .string(let stringValue) = value {
            return stringValue
        }
        return nil
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
