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
    var performHandshakeClosure: @Sendable () async throws -> Handshake
    var fetchStateClosure: @Sendable () async throws -> SessionState
    var updateStateClosure: @Sendable (SessionUpdate) async throws -> SessionState
    var checkCompatibilityClosure: @Sendable () async throws -> Compatibility
    var cacheStateClosure: @Sendable (SessionState) async throws -> Void
    var loadCachedStateClosure: @Sendable () async throws -> CachedSnapshot<SessionState>?

    init(
        performHandshake: @escaping @Sendable () async throws -> Handshake,
        fetchState: @escaping @Sendable () async throws -> SessionState,
        updateState: @escaping @Sendable (SessionUpdate) async throws -> SessionState,
        checkCompatibility: @escaping @Sendable () async throws -> Compatibility,
        cacheState: @escaping @Sendable (SessionState) async throws -> Void = { _ in },
        loadCachedState: @escaping @Sendable () async throws -> CachedSnapshot<SessionState>? = {
            nil
        }
    ) {
        self.performHandshakeClosure = performHandshake
        self.fetchStateClosure = fetchState
        self.updateStateClosure = updateState
        self.checkCompatibilityClosure = checkCompatibility
        self.cacheStateClosure = cacheState
        self.loadCachedStateClosure = loadCachedState
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

    func cacheState(_ state: SessionState) async throws {
        try await cacheStateClosure(state)
    }

    func loadCachedState() async throws -> CachedSnapshot<SessionState>? {
        try await loadCachedStateClosure()
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
        mapper: TransmissionDomainMapper = .init(),
        snapshot: OfflineCacheClient? = nil
    ) -> SessionRepository {
        let cacheState: @Sendable (SessionState) async throws -> Void = { state in
            guard let snapshot else { return }
            do {
                _ = try await snapshot.updateSession(state)
            } catch OfflineCacheError.exceedsSizeLimit {
                try await snapshot.clear()
            }
        }

        let loadCachedState: @Sendable () async throws -> CachedSnapshot<SessionState>? = {
            guard let snapshot else { return nil }
            return try await snapshot.load()?.session
        }

        return SessionRepository(
            performHandshake: {
                try await transmissionClient.performHandshake()
                    .asSessionRepositoryHandshake()
            },
            fetchState: {
                try await fetchSessionState(
                    transmissionClient: transmissionClient,
                    mapper: mapper,
                    cacheState: cacheState
                )
            },
            updateState: { update in
                let arguments = makeSessionSetArguments(update: update)
                if let arguments {
                    _ = try await transmissionClient.sessionSet(arguments)
                }
                return try await fetchSessionState(
                    transmissionClient: transmissionClient,
                    mapper: mapper,
                    cacheState: cacheState
                )
            },
            checkCompatibility: {
                let result = try await transmissionClient.performHandshake()
                return SessionRepository.Compatibility(
                    isCompatible: result.isCompatible,
                    rpcVersion: result.rpcVersion
                )
            },
            cacheState: cacheState,
            loadCachedState: loadCachedState
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
