import Foundation

/// Протокол для клиента взаимодействия с Transmission RPC API.
/// Определяет контракт для всех методов, необходимых MVP (session-get, torrent-get/add/start/stop/remove).
/// Конкретную реализацию с URLSession подключают через DI.
public protocol TransmissionClientProtocol: Sendable {
    /// Type aliases для компактности сигнатур методов
    typealias TorrentIDs = [Int]
    typealias ClientResult = TransmissionResponse

    /// Получить информацию о текущей сессии и версии Transmission.
    /// Используется при рукопожатии для проверки совместимости версии (минимум 3.0).
    func sessionGet() async throws -> ClientResult

    /// Установить параметры сессии (например, лимиты скоростей).
    func sessionSet(arguments: AnyCodable) async throws -> ClientResult

    /// Получить статистику сессии (активные торренты, скорости, счётчики).
    func sessionStats() async throws -> ClientResult

    /// Получить информацию о торрентах.
    /// - Parameters:
    ///   - ids: Опциональный массив ID торрентов для фильтрации.
    ///   - fields: Опциональный массив полей для оптимизации ответа.
    func torrentGet(ids: TorrentIDs?, fields: [String]?) async throws -> ClientResult

    /// Добавить новый торрент из файла, magnet-ссылки или URL.
    /// - Parameters:
    ///   - filename: Путь к файлу, URL или magnet-ссылка. Опционально, если используется `metainfo`.
    ///   - metainfo: Base64-исходные данные `.torrent` файла (сырые байты до кодирования). Опционально, если используется `filename`.
    ///   - downloadDir: Опциональная директория для загрузки.
    ///   - paused: Запустить ли торрент в режиме паузы.
    ///   - labels: Опциональные теги для торрента.
    func torrentAdd(
        filename: String?,
        metainfo: Data?,
        downloadDir: String?,
        paused: Bool?,
        labels: [String]?
    ) async throws -> ClientResult

    /// Запустить один или несколько торрентов.
    func torrentStart(ids: TorrentIDs) async throws -> ClientResult

    /// Остановить один или несколько торрентов.
    func torrentStop(ids: TorrentIDs) async throws -> ClientResult

    /// Удалить один или несколько торрентов.
    /// - Parameters:
    ///   - ids: Массив ID торрентов.
    ///   - deleteLocalData: Удалять ли локальные файлы торрента.
    func torrentRemove(ids: TorrentIDs, deleteLocalData: Bool?) async throws -> ClientResult

    /// Установить параметры для одного или нескольких торрентов (приоритеты, лимиты).
    func torrentSet(ids: TorrentIDs, arguments: AnyCodable) async throws -> ClientResult

    /// Проверить целостность торрента (долгая операция).
    func torrentVerify(ids: TorrentIDs) async throws -> ClientResult

    /// Checks server version compatibility with the minimum required Transmission version (3.0+, RPC v14).
    ///
    /// - Returns: A tuple containing compatibility status and the RPC version number.
    /// - Throws: `APIError.versionUnsupported` if server version is below minimum (RPC v14),
    ///           `APIError.decodingFailed` if unable to parse version information.
    func checkServerVersion() async throws -> (compatible: Bool, rpcVersion: Int)
}
