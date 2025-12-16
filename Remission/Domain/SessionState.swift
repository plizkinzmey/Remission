import Foundation

// swiftlint:disable nesting

/// Доменное представление состояния сессии Transmission.
/// Комбинирует данные `session-get` и `session-stats`.
public struct SessionState: Equatable, Sendable, Codable {
    public struct RPC: Equatable, Sendable, Codable {
        /// Версия RPC API (`session-get` → `rpc-version`).
        public var rpcVersion: Int
        /// Минимальная поддерживаемая версия (`session-get` → `rpc-version-minimum`).
        public var rpcVersionMinimum: Int
        /// Версия демона (`session-get` → `version`).
        public var serverVersion: String

        public init(rpcVersion: Int, rpcVersionMinimum: Int, serverVersion: String) {
            self.rpcVersion = rpcVersion
            self.rpcVersionMinimum = rpcVersionMinimum
            self.serverVersion = serverVersion
        }
    }

    public struct SpeedLimits: Equatable, Sendable, Codable {
        /// Глобальный лимит скачивания (`session-get` → `speed-limit-down`, `speed-limit-down-enabled`).
        public var download: Limit
        /// Глобальный лимит отдачи (`session-get` → `speed-limit-up`, `speed-limit-up-enabled`).
        public var upload: Limit
        /// Альтернативный режим скоростей (`session-get` → `alt-speed-enabled`, `alt-speed-down`, `alt-speed-up`).
        public var alternative: Alternative

        public init(download: Limit, upload: Limit, alternative: Alternative) {
            self.download = download
            self.upload = upload
            self.alternative = alternative
        }

        public struct Limit: Equatable, Sendable, Codable {
            public var isEnabled: Bool
            /// Значение лимита в КБ/с.
            public var kilobytesPerSecond: Int

            public init(isEnabled: Bool, kilobytesPerSecond: Int) {
                self.isEnabled = isEnabled
                self.kilobytesPerSecond = kilobytesPerSecond
            }
        }

        public struct Alternative: Equatable, Sendable, Codable {
            public var isEnabled: Bool
            public var downloadKilobytesPerSecond: Int
            public var uploadKilobytesPerSecond: Int

            public init(
                isEnabled: Bool,
                downloadKilobytesPerSecond: Int,
                uploadKilobytesPerSecond: Int
            ) {
                self.isEnabled = isEnabled
                self.downloadKilobytesPerSecond = downloadKilobytesPerSecond
                self.uploadKilobytesPerSecond = uploadKilobytesPerSecond
            }
        }
    }

    public struct Queue: Equatable, Sendable, Codable {
        /// Лимит на количество скачивающих торрентов (`session-get` → `download-queue-size`, `download-queue-enabled`).
        public var downloadLimit: QueueLimit
        /// Лимит на количество раздающих торрентов (`session-get` → `seed-queue-size`, `seed-queue-enabled`).
        public var seedLimit: QueueLimit
        /// Учитывать ли простаивающие торренты (`session-get` → `queue-stalled-enabled`, `queue-stalled-minutes`).
        public var considerStalled: Bool
        public var stalledMinutes: Int

        public init(
            downloadLimit: QueueLimit,
            seedLimit: QueueLimit,
            considerStalled: Bool,
            stalledMinutes: Int
        ) {
            self.downloadLimit = downloadLimit
            self.seedLimit = seedLimit
            self.considerStalled = considerStalled
            self.stalledMinutes = stalledMinutes
        }

        public struct QueueLimit: Equatable, Sendable, Codable {
            public var isEnabled: Bool
            public var count: Int

            public init(isEnabled: Bool, count: Int) {
                self.isEnabled = isEnabled
                self.count = count
            }
        }
    }

    public struct Throughput: Equatable, Sendable, Codable {
        /// Текущее количество активных торрентов (`session-stats` → `activeTorrentCount`).
        public var activeTorrentCount: Int
        /// Количество приостановленных торрентов (`session-stats` → `pausedTorrentCount`).
        public var pausedTorrentCount: Int
        /// Общее количество торрентов (`session-stats` → `torrentCount`).
        public var totalTorrentCount: Int
        /// Текущая скорость скачивания в байт/с (`session-stats` → `downloadSpeed`).
        public var downloadSpeed: Int
        /// Текущая скорость отдачи в байт/с (`session-stats` → `uploadSpeed`).
        public var uploadSpeed: Int

        public init(
            activeTorrentCount: Int,
            pausedTorrentCount: Int,
            totalTorrentCount: Int,
            downloadSpeed: Int,
            uploadSpeed: Int
        ) {
            self.activeTorrentCount = activeTorrentCount
            self.pausedTorrentCount = pausedTorrentCount
            self.totalTorrentCount = totalTorrentCount
            self.downloadSpeed = downloadSpeed
            self.uploadSpeed = uploadSpeed
        }
    }

    public struct LifetimeStats: Equatable, Sendable, Codable {
        /// Количество добавленных файлов (`*stats` → `filesAdded`).
        public var filesAdded: Int
        /// Скачано байтов (`*stats` → `downloadedBytes`).
        public var downloadedBytes: Int64
        /// Отдано байтов (`*stats` → `uploadedBytes`).
        public var uploadedBytes: Int64
        /// Количество сессий (`*stats` → `sessionCount`).
        public var sessionCount: Int
        /// Суммарное время активности в секундах (`*stats` → `secondsActive`).
        public var secondsActive: Int

        public init(
            filesAdded: Int,
            downloadedBytes: Int64,
            uploadedBytes: Int64,
            sessionCount: Int,
            secondsActive: Int
        ) {
            self.filesAdded = filesAdded
            self.downloadedBytes = downloadedBytes
            self.uploadedBytes = uploadedBytes
            self.sessionCount = sessionCount
            self.secondsActive = secondsActive
        }

        /// Условный коэффициент отдачи (может быть `Double.infinity`).
        public var ratio: Double {
            guard downloadedBytes > 0 else { return .infinity }
            return Double(uploadedBytes) / Double(downloadedBytes)
        }
    }

    public var rpc: RPC
    /// Директория загрузки по умолчанию (`session-get` → `download-dir`).
    public var downloadDirectory: String
    public var speedLimits: SpeedLimits
    public var queue: Queue
    public var throughput: Throughput
    /// Кумулятивная статистика (`session-stats` → `cumulative-stats`).
    public var cumulativeStats: LifetimeStats
    /// Текущая статистика (`session-stats` → `current-stats`).
    public var currentStats: LifetimeStats

    public init(
        rpc: RPC,
        downloadDirectory: String,
        speedLimits: SpeedLimits,
        queue: Queue,
        throughput: Throughput,
        cumulativeStats: LifetimeStats,
        currentStats: LifetimeStats
    ) {
        self.rpc = rpc
        self.downloadDirectory = downloadDirectory
        self.speedLimits = speedLimits
        self.queue = queue
        self.throughput = throughput
        self.cumulativeStats = cumulativeStats
        self.currentStats = currentStats
    }
}

// MARK: - Preview Fixtures

extension SessionState {
    /// Пример активной сессии с включёнными лимитами.
    public static let previewActive: SessionState = {
        SessionState(
            rpc: .init(rpcVersion: 17, rpcVersionMinimum: 14, serverVersion: "4.0.4"),
            downloadDirectory: "/downloads",
            speedLimits: .init(
                download: .init(isEnabled: true, kilobytesPerSecond: 8192),
                upload: .init(isEnabled: true, kilobytesPerSecond: 2048),
                alternative: .init(
                    isEnabled: false,
                    downloadKilobytesPerSecond: 2048,
                    uploadKilobytesPerSecond: 512
                )
            ),
            queue: .init(
                downloadLimit: .init(isEnabled: true, count: 5),
                seedLimit: .init(isEnabled: true, count: 4),
                considerStalled: true,
                stalledMinutes: 30
            ),
            throughput: .init(
                activeTorrentCount: 6,
                pausedTorrentCount: 12,
                totalTorrentCount: 42,
                downloadSpeed: 9_500_000,
                uploadSpeed: 1_200_000
            ),
            cumulativeStats: .init(
                filesAdded: 542,
                downloadedBytes: 8_450_000_000_000,
                uploadedBytes: 12_700_000_000_000,
                sessionCount: 120,
                secondsActive: 9_331_200
            ),
            currentStats: .init(
                filesAdded: 6,
                downloadedBytes: 85_000_000_000,
                uploadedBytes: 62_000_000_000,
                sessionCount: 3,
                secondsActive: 86_400
            )
        )
    }()

    /// Пример сессии с альтернативными лимитами и отключёнными очередями.
    public static let previewLimited: SessionState = {
        SessionState(
            rpc: .init(rpcVersion: 17, rpcVersionMinimum: 14, serverVersion: "3.00"),
            downloadDirectory: "/downloads",
            speedLimits: .init(
                download: .init(isEnabled: false, kilobytesPerSecond: 0),
                upload: .init(isEnabled: false, kilobytesPerSecond: 0),
                alternative: .init(
                    isEnabled: true,
                    downloadKilobytesPerSecond: 1024,
                    uploadKilobytesPerSecond: 256
                )
            ),
            queue: .init(
                downloadLimit: .init(isEnabled: false, count: 0),
                seedLimit: .init(isEnabled: false, count: 0),
                considerStalled: false,
                stalledMinutes: 0
            ),
            throughput: .init(
                activeTorrentCount: 0,
                pausedTorrentCount: 8,
                totalTorrentCount: 12,
                downloadSpeed: 0,
                uploadSpeed: 0
            ),
            cumulativeStats: .init(
                filesAdded: 120,
                downloadedBytes: 1_200_000_000_000,
                uploadedBytes: 1_050_000_000_000,
                sessionCount: 35,
                secondsActive: 1_814_400
            ),
            currentStats: .init(
                filesAdded: 0,
                downloadedBytes: 0,
                uploadedBytes: 0,
                sessionCount: 0,
                secondsActive: 3600
            )
        )
    }()
}

// swiftlint:enable nesting
