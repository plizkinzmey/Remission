import Foundation

#if canImport(ComposableArchitecture)
    import ComposableArchitecture
    import Dependencies
#endif

/// Контракт для работы с сессией Transmission на доменном уровне.
protocol SessionRepositoryProtocol: Sendable {
    func performHandshake() async throws -> SessionRepository.Handshake
    func fetchState() async throws -> SessionState
    func updateState(_ update: SessionRepository.SessionUpdate) async throws -> SessionState
    func checkCompatibility() async throws -> SessionRepository.Compatibility
}

/// Структура для интеграции с `DependencyKey` и TCA.
struct SessionRepository: Sendable, SessionRepositoryProtocol {
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

        public init(speedLimits: SpeedLimitsUpdate? = nil, queue: QueueUpdate? = nil) {
            self.speedLimits = speedLimits
            self.queue = queue
        }

        /// `true`, если обновление не содержит ни одного изменения.
        var isEmpty: Bool {
            speedLimits == nil && queue == nil
        }
    }

    var performHandshakeClosure: @Sendable () async throws -> Handshake
    var fetchStateClosure: @Sendable () async throws -> SessionState
    var updateStateClosure: @Sendable (SessionUpdate) async throws -> SessionState
    var checkCompatibilityClosure: @Sendable () async throws -> Compatibility

    init(
        performHandshake: @escaping @Sendable () async throws -> Handshake,
        fetchState: @escaping @Sendable () async throws -> SessionState,
        updateState: @escaping @Sendable (SessionUpdate) async throws -> SessionState,
        checkCompatibility: @escaping @Sendable () async throws -> Compatibility
    ) {
        self.performHandshakeClosure = performHandshake
        self.fetchStateClosure = fetchState
        self.updateStateClosure = updateState
        self.checkCompatibilityClosure = checkCompatibility
    }

    func performHandshake() async throws -> Handshake {
        try await performHandshakeClosure()
    }

    func fetchState() async throws -> SessionState {
        try await fetchStateClosure()
    }

    func updateState(_ update: SessionUpdate) async throws -> SessionState {
        try await updateStateClosure(update)
    }

    func checkCompatibility() async throws -> Compatibility {
        try await checkCompatibilityClosure()
    }
}

#if canImport(ComposableArchitecture)
    extension SessionRepository: DependencyKey {
        static var liveValue: SessionRepository {
            @Dependency(\.transmissionClient) var transmissionClient
            return .live(transmissionClient: transmissionClient)
        }
        static var previewValue: SessionRepository {
            let store = InMemorySessionRepositoryStore(
                handshake: .init(
                    sessionID: "preview-session",
                    rpcVersion: 17,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: "Transmission 4.0",
                    isCompatible: true
                ),
                state: .previewActive,
                compatibility: .init(isCompatible: true, rpcVersion: 17)
            )
            return .inMemory(store: store)
        }
        static var testValue: SessionRepository {
            let store = InMemorySessionRepositoryStore(
                handshake: .init(
                    sessionID: nil,
                    rpcVersion: 17,
                    minimumSupportedRpcVersion: 14,
                    serverVersionDescription: "Transmission Test 4.0",
                    isCompatible: true
                ),
                state: .previewActive,
                compatibility: .init(isCompatible: true, rpcVersion: 17)
            )
            return .inMemory(store: store)
        }
    }

    extension DependencyValues {
        var sessionRepository: SessionRepository {
            get { self[SessionRepository.self] }
            set { self[SessionRepository.self] = newValue }
        }
    }
#endif

extension SessionRepository {
    /// Live-реализация, основанная на TransmissionClientDependency и доменном маппере.
    static func live(
        transmissionClient: TransmissionClientDependency,
        mapper: TransmissionDomainMapper = .init()
    ) -> SessionRepository {
        SessionRepository(
            performHandshake: {
                try await transmissionClient.performHandshake()
                    .asSessionRepositoryHandshake()
            },
            fetchState: {
                let session = try await transmissionClient.sessionGet()
                let stats = try await transmissionClient.sessionStats()
                return try mapper.mapSessionState(
                    sessionResponse: session,
                    statsResponse: stats
                )
            },
            updateState: { update in
                let arguments = makeSessionSetArguments(update: update)
                guard let arguments else {
                    return try await SessionRepository.live(
                        transmissionClient: transmissionClient,
                        mapper: mapper
                    ).fetchState()
                }
                _ = try await transmissionClient.sessionSet(arguments)
                let session = try await transmissionClient.sessionGet()
                let stats = try await transmissionClient.sessionStats()
                return try mapper.mapSessionState(
                    sessionResponse: session,
                    statsResponse: stats
                )
            },
            checkCompatibility: {
                let result = try await transmissionClient.performHandshake()
                return SessionRepository.Compatibility(
                    isCompatible: result.isCompatible,
                    rpcVersion: result.rpcVersion
                )
            }
        )
    }
}

private func makeSessionSetArguments(
    update: SessionRepository.SessionUpdate
) -> AnyCodable? {
    var dict: [String: AnyCodable] = [:]

    if let speedLimits = update.speedLimits {
        if let download = speedLimits.download {
            dict["speed-limit-down-enabled"] = .bool(download.isEnabled)
            dict["speed-limit-down"] = .int(download.kilobytesPerSecond)
        }
        if let upload = speedLimits.upload {
            dict["speed-limit-up-enabled"] = .bool(upload.isEnabled)
            dict["speed-limit-up"] = .int(upload.kilobytesPerSecond)
        }
        if let alt = speedLimits.alternative {
            dict["alt-speed-enabled"] = .bool(alt.isEnabled)
            dict["alt-speed-down"] = .int(alt.downloadKilobytesPerSecond)
            dict["alt-speed-up"] = .int(alt.uploadKilobytesPerSecond)
        }
    }

    if let queue = update.queue {
        if let downloadLimit = queue.downloadLimit {
            dict["download-queue-enabled"] = .bool(downloadLimit.isEnabled)
            dict["download-queue-size"] = .int(downloadLimit.count)
        }
        if let seedLimit = queue.seedLimit {
            dict["seed-queue-enabled"] = .bool(seedLimit.isEnabled)
            dict["seed-queue-size"] = .int(seedLimit.count)
        }
        if let considerStalled = queue.considerStalled {
            dict["queue-stalled-enabled"] = .bool(considerStalled)
        }
        if let stalledMinutes = queue.stalledMinutes {
            dict["queue-stalled-minutes"] = .int(stalledMinutes)
        }
    }

    guard dict.isEmpty == false else { return nil }
    return .object(dict)
}

extension TransmissionHandshakeResult {
    fileprivate func asSessionRepositoryHandshake() -> SessionRepository.Handshake {
        SessionRepository.Handshake(
            sessionID: sessionID,
            rpcVersion: rpcVersion,
            minimumSupportedRpcVersion: minimumSupportedRpcVersion,
            serverVersionDescription: serverVersionDescription,
            isCompatible: isCompatible
        )
    }
}

extension SessionRepository {
    static let placeholder: SessionRepository = SessionRepository(
        performHandshake: {
            Handshake(
                sessionID: nil,
                rpcVersion: 0,
                minimumSupportedRpcVersion: 0,
                serverVersionDescription: nil,
                isCompatible: false
            )
        },
        fetchState: {
            .previewActive
        },
        updateState: { _ in
            .previewActive
        },
        checkCompatibility: {
            Compatibility(isCompatible: true, rpcVersion: 0)
        }
    )

    static let unimplemented: SessionRepository = SessionRepository(
        performHandshake: {
            throw SessionRepositoryError.notConfigured("performHandshake")
        },
        fetchState: {
            throw SessionRepositoryError.notConfigured("fetchState")
        },
        updateState: { _ in
            throw SessionRepositoryError.notConfigured("updateState")
        },
        checkCompatibility: {
            throw SessionRepositoryError.notConfigured("checkCompatibility")
        }
    )
}

private enum SessionRepositoryError: Error, LocalizedError, Sendable {
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let name):
            return "SessionRepository.\(name) is not configured for this environment."
        }
    }
}
