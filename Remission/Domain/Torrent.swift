import Foundation

// swiftlint:disable nesting

/// Доменная модель торрента Transmission.
/// Объединяет краткое (`Summary`) и детализированное (`Details`) представление,
/// чтобы одна структура могла обслуживать список и экран деталей.
/// Все поля документированы ссылками на исходные Transmission RPC поля.
public struct Torrent: Equatable, Sendable, Identifiable, Codable {
    /// Уникальный идентификатор торрента (`torrent-get` → `id`).
    public struct Identifier: RawRepresentable, Hashable, Sendable, Codable {
        public var rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public var id: Identifier
    public var name: String
    public var status: Status
    /// Список тегов (`torrent-get` → `labels`).
    public var tags: [String]
    public var summary: Summary
    public var details: Details?

    public init(
        id: Identifier,
        name: String,
        status: Status,
        tags: [String] = [],
        summary: Summary,
        details: Details? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.tags = tags
        self.summary = summary
        self.details = details
    }
}

extension Torrent {
    /// Статус из Transmission (`torrent-get` → `status`).
    public enum Status: Int, Equatable, Sendable, Codable {
        /// 0 – останавливается/остановлен.
        case stopped = 0
        /// 1 – ожидает проверку.
        case checkWaiting = 1
        /// 2 – выполняется проверка.
        case checking = 2
        /// 3 – ожидает скачивания в очереди.
        case downloadWaiting = 3
        /// 4 – активное скачивание.
        case downloading = 4
        /// 5 – ожидает раздачи.
        case seedWaiting = 5
        /// 6 – активная раздача.
        case seeding = 6
        /// 7 – изолирован (no data) — редкое состояние.
        case isolated = 7
    }

    /// Краткая сводка, используемая списком торрентов.
    public struct Summary: Equatable, Sendable, Codable {
        public var progress: Progress
        public var transfer: Transfer
        public var peers: Peers

        public init(progress: Progress, transfer: Transfer, peers: Peers) {
            self.progress = progress
            self.transfer = transfer
            self.peers = peers
        }
    }

    /// Прогресс по размеру и времени (`torrent-get` → `percentDone`, `totalSize`, `downloadedEver`, `uploadedEver`, `eta`).
    public struct Progress: Equatable, Sendable, Codable {
        public var percentDone: Double
        public var totalSize: Int
        public var downloadedEver: Int
        public var uploadedEver: Int
        /// Отношение отданного к загруженному (`torrent-get` → `uploadRatio`).
        public var uploadRatio: Double
        /// ETA в секундах, `-1` если неизвестно.
        public var etaSeconds: Int

        public init(
            percentDone: Double,
            totalSize: Int,
            downloadedEver: Int,
            uploadedEver: Int,
            uploadRatio: Double,
            etaSeconds: Int
        ) {
            self.percentDone = percentDone
            self.totalSize = totalSize
            self.downloadedEver = downloadedEver
            self.uploadedEver = uploadedEver
            self.uploadRatio = uploadRatio
            self.etaSeconds = etaSeconds
        }
    }

    /// Текущие скорости и лимиты (`torrent-get` → `rateDownload`, `rateUpload`, `downloadLimit`, `downloadLimited`, `uploadLimit`, `uploadLimited`).
    public struct Transfer: Equatable, Sendable, Codable {
        public struct SpeedLimit: Equatable, Sendable, Codable {
            /// Флаг `*_limited` о включённости глобального лимита.
            public var isEnabled: Bool
            /// Значение лимита в КБ/c (`downloadLimit`, `uploadLimit`).
            public var kilobytesPerSecond: Int

            public init(isEnabled: Bool, kilobytesPerSecond: Int) {
                self.isEnabled = isEnabled
                self.kilobytesPerSecond = kilobytesPerSecond
            }
        }

        /// Текущая скорость скачивания в байт/с (`rateDownload`).
        public var downloadRate: Int
        /// Текущая скорость отдачи в байт/с (`rateUpload`).
        public var uploadRate: Int
        public var downloadLimit: SpeedLimit
        public var uploadLimit: SpeedLimit

        public init(
            downloadRate: Int,
            uploadRate: Int,
            downloadLimit: SpeedLimit,
            uploadLimit: SpeedLimit
        ) {
            self.downloadRate = downloadRate
            self.uploadRate = uploadRate
            self.downloadLimit = downloadLimit
            self.uploadLimit = uploadLimit
        }
    }

    /// Информация о пирах (`torrent-get` → `peersConnected`, `peersFrom`).
    public struct Peers: Equatable, Sendable, Codable {
        /// Количество активно подключённых пиров (`peersConnected`).
        public var connected: Int
        /// Источники пиров с количеством.
        public var sources: [PeerSource]

        public init(connected: Int, sources: [PeerSource]) {
            self.connected = connected
            self.sources = sources
        }
    }

    /// Источник пиров (`torrent-get` → `peersFrom`).
    public struct PeerSource: Equatable, Sendable, Identifiable, Codable {
        /// Ключ источника (`peersFrom` → ключ словаря, например `fromCache`).
        public var id: String { name }
        public var name: String
        public var count: Int

        public init(name: String, count: Int) {
            self.name = name
            self.count = count
        }
    }

    /// Детализированная часть для экрана подробностей.
    public struct Details: Equatable, Sendable, Codable {
        /// Путь загрузки (`torrent-get` → `downloadDir`).
        public var downloadDirectory: String
        /// Дата добавления торрента (`torrent-get` → `dateAdded`, Unix timestamp).
        public var addedDate: Date?
        /// Файлы торрента (`torrent-get` → `files`).
        public var files: [File]
        /// Список трекеров (`torrent-get` → `trackers`).
        public var trackers: [Tracker]
        /// Статистика трекеров (`torrent-get` → `trackerStats`).
        public var trackerStats: [TrackerStat]
        /// История скоростей для диаграмм.
        public var speedSamples: [SpeedSample]

        public init(
            downloadDirectory: String,
            addedDate: Date?,
            files: [File],
            trackers: [Tracker],
            trackerStats: [TrackerStat],
            speedSamples: [SpeedSample]
        ) {
            self.downloadDirectory = downloadDirectory
            self.addedDate = addedDate
            self.files = files
            self.trackers = trackers
            self.trackerStats = trackerStats
            self.speedSamples = speedSamples
        }
    }

    /// Файл из массива `files`.
    public struct File: Equatable, Sendable, Identifiable, Codable {
        public var id: Int { index }
        /// Индекс файла (`files[index]`).
        public var index: Int
        /// Полное имя (`files[index].name`).
        public var name: String
        /// Общий размер в байтах (`files[index].length`).
        public var length: Int
        /// Скачано в байтах (`files[index].bytesCompleted`).
        public var bytesCompleted: Int
        /// Приоритет (`files[index].priority`).
        public var priority: Int
        /// Флаг "востребован" (`files[index].wanted`).
        public var wanted: Bool

        public init(
            index: Int,
            name: String,
            length: Int,
            bytesCompleted: Int,
            priority: Int,
            wanted: Bool
        ) {
            self.index = index
            self.name = name
            self.length = length
            self.bytesCompleted = bytesCompleted
            self.priority = priority
            self.wanted = wanted
        }
    }

    /// Трекер (`trackers`).
    public struct Tracker: Equatable, Sendable, Identifiable, Codable {
        /// Встроенный идентификатор (`trackers[index].id`).
        public var id: Int
        /// Адрес анонса (`trackers[index].announce`).
        public var announce: String
        /// Очередь/уровень трекера (`trackers[index].tier`).
        public var tier: Int

        public init(id: Int, announce: String, tier: Int) {
            self.id = id
            self.announce = announce
            self.tier = tier
        }
    }

    /// Статистика трекера (`trackerStats`).
    public struct TrackerStat: Equatable, Sendable, Identifiable, Codable {
        public var id: Int { trackerId }
        /// Идентификатор трекера (`trackerStats[index].id`).
        public var trackerId: Int
        public var lastAnnounceResult: String
        public var downloadCount: Int
        public var leecherCount: Int
        public var seederCount: Int

        public init(
            trackerId: Int,
            lastAnnounceResult: String,
            downloadCount: Int,
            leecherCount: Int,
            seederCount: Int
        ) {
            self.trackerId = trackerId
            self.lastAnnounceResult = lastAnnounceResult
            self.downloadCount = downloadCount
            self.leecherCount = leecherCount
            self.seederCount = seederCount
        }
    }

    /// Сэмпл скоростей для графика.
    public struct SpeedSample: Equatable, Sendable, Codable {
        public var timestamp: Date
        public var downloadRate: Int
        public var uploadRate: Int

        public init(timestamp: Date, downloadRate: Int, uploadRate: Int) {
            self.timestamp = timestamp
            self.downloadRate = downloadRate
            self.uploadRate = uploadRate
        }
    }
}

// MARK: - Preview Fixtures

extension Torrent {
    /// Активное скачивание с несколькими источниками.
    public static let previewDownloading: Torrent = {
        let summary = Summary(
            progress: Progress(
                percentDone: 0.42,
                totalSize: 15_728_640_000,
                downloadedEver: 6_500_000_000,
                uploadedEver: 1_200_000_000,
                uploadRatio: 0.18,
                etaSeconds: 3600
            ),
            transfer: Transfer(
                downloadRate: 3_200_000,
                uploadRate: 420_000,
                downloadLimit: Transfer.SpeedLimit(isEnabled: false, kilobytesPerSecond: 0),
                uploadLimit: Transfer.SpeedLimit(isEnabled: true, kilobytesPerSecond: 500)
            ),
            peers: Peers(
                connected: 18,
                sources: [
                    PeerSource(name: "fromCache", count: 4),
                    PeerSource(name: "fromDht", count: 9),
                    PeerSource(name: "fromTracker", count: 5)
                ]
            )
        )

        let details = Details(
            downloadDirectory: "/Volumes/Media/Ubuntu",
            addedDate: Date(timeIntervalSince1970: 1_697_000_000),
            files: [
                File(
                    index: 0,
                    name: "ubuntu-24.04-desktop.iso",
                    length: 5_368_709_120,
                    bytesCompleted: 2_475_000_000,
                    priority: 0,
                    wanted: true
                ),
                File(
                    index: 1,
                    name: "ubuntu-24.04-desktop.iso.zsync",
                    length: 150_000,
                    bytesCompleted: 150_000,
                    priority: 0,
                    wanted: false
                )
            ],
            trackers: [
                Tracker(id: 10, announce: "https://tracker.example.com/announce", tier: 0),
                Tracker(id: 11, announce: "udp://tracker.openbittorrent.com:80", tier: 1)
            ],
            trackerStats: [
                TrackerStat(
                    trackerId: 10,
                    lastAnnounceResult: "success",
                    downloadCount: 3,
                    leecherCount: 12,
                    seederCount: 45
                )
            ],
            speedSamples: (0..<12).map { index in
                SpeedSample(
                    timestamp: Date().addingTimeInterval(Double(-index) * 60),
                    downloadRate: 2_500_000 + (index * 50_000),
                    uploadRate: 350_000 + (index * 25_000)
                )
            }
        )

        return Torrent(
            id: Identifier(rawValue: 1),
            name: "Ubuntu 24.04 Desktop",
            status: .downloading,
            tags: ["linux", "lts"],
            summary: summary,
            details: details
        )
    }()

    /// Завершённый торрент для списка.
    public static let previewCompleted: Torrent = {
        let summary = Summary(
            progress: Progress(
                percentDone: 1.0,
                totalSize: 42_949_672_960,
                downloadedEver: 42_949_672_960,
                uploadedEver: 84_000_000_000,
                uploadRatio: 1.95,
                etaSeconds: -1
            ),
            transfer: Transfer(
                downloadRate: 0,
                uploadRate: 250_000,
                downloadLimit: Transfer.SpeedLimit(isEnabled: false, kilobytesPerSecond: 0),
                uploadLimit: Transfer.SpeedLimit(isEnabled: true, kilobytesPerSecond: 1024)
            ),
            peers: Peers(
                connected: 6,
                sources: [
                    PeerSource(name: "fromTracker", count: 4),
                    PeerSource(name: "fromLpd", count: 2)
                ]
            )
        )

        return Torrent(
            id: Identifier(rawValue: 2),
            name: "The Expanse Season 6",
            status: .seeding,
            tags: ["series"],
            summary: summary,
            details: nil
        )
    }()
}

// swiftlint:enable nesting
