import Foundation

extension SessionRepository {
    struct Handshake: Equatable, Sendable {
        /// Текущий session-id, если он предоставлен Transmission.
        var sessionID: String?
        /// Поддерживаемая RPC версия сервера.
        var rpcVersion: Int
        /// Минимальная поддерживаемая клиентом версия RPC.
        var minimumSupportedRpcVersion: Int
        /// Человекочитаемая версия демона Transmission.
        var serverVersionDescription: String?
        /// Флаг совместимости клиента и сервера.
        var isCompatible: Bool

        public init(
            sessionID: String?,
            rpcVersion: Int,
            minimumSupportedRpcVersion: Int,
            serverVersionDescription: String?,
            isCompatible: Bool
        ) {
            self.sessionID = sessionID
            self.rpcVersion = rpcVersion
            self.minimumSupportedRpcVersion = minimumSupportedRpcVersion
            self.serverVersionDescription = serverVersionDescription
            self.isCompatible = isCompatible
        }
    }

    struct Compatibility: Equatable, Sendable {
        var isCompatible: Bool
        var rpcVersion: Int

        public init(isCompatible: Bool, rpcVersion: Int) {
            self.isCompatible = isCompatible
            self.rpcVersion = rpcVersion
        }
    }

    struct SpeedLimitsUpdate: Equatable, Sendable {
        var download: SessionState.SpeedLimits.Limit?
        var upload: SessionState.SpeedLimits.Limit?
        var alternative: SessionState.SpeedLimits.Alternative?

        public init(
            download: SessionState.SpeedLimits.Limit? = nil,
            upload: SessionState.SpeedLimits.Limit? = nil,
            alternative: SessionState.SpeedLimits.Alternative? = nil
        ) {
            self.download = download
            self.upload = upload
            self.alternative = alternative
        }
    }

    struct QueueUpdate: Equatable, Sendable {
        var downloadLimit: SessionState.Queue.QueueLimit?
        var seedLimit: SessionState.Queue.QueueLimit?
        var considerStalled: Bool?
        var stalledMinutes: Int?

        public init(
            downloadLimit: SessionState.Queue.QueueLimit? = nil,
            seedLimit: SessionState.Queue.QueueLimit? = nil,
            considerStalled: Bool? = nil,
            stalledMinutes: Int? = nil
        ) {
            self.downloadLimit = downloadLimit
            self.seedLimit = seedLimit
            self.considerStalled = considerStalled
            self.stalledMinutes = stalledMinutes
        }
    }

    struct SessionUpdate: Equatable, Sendable {
        /// Обновления лимитов скоростей. `nil` — оставить без изменений.
        var speedLimits: SpeedLimitsUpdate?
        /// Обновления очередей. `nil` — оставить без изменений.
        var queue: QueueUpdate?
        /// Обновление лимита рейтинга раздачи. `nil` — оставить без изменений.
        var seedRatioLimit: SessionState.SeedRatioLimit?

        public init(
            speedLimits: SpeedLimitsUpdate? = nil,
            queue: QueueUpdate? = nil,
            seedRatioLimit: SessionState.SeedRatioLimit? = nil
        ) {
            self.speedLimits = speedLimits
            self.queue = queue
            self.seedRatioLimit = seedRatioLimit
        }

        /// `true`, если обновление не содержит ни одного изменения.
        var isEmpty: Bool {
            speedLimits == nil && queue == nil && seedRatioLimit == nil
        }
    }
}
