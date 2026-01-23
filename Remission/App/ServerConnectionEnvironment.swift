import ComposableArchitecture
import Foundation

/// Содержит сервер-специфические зависимости, необходимые для экрана подробностей.
struct ServerConnectionEnvironment: Sendable {
    struct DependencyOverrides: Sendable {
        var transmissionClient: TransmissionClientDependency
        var torrentRepository: TorrentRepository
        var sessionRepository: SessionRepository
    }

    var serverID: UUID
    var fingerprint: String
    var dependencies: DependencyOverrides
    var cacheKey: OfflineCacheKey
    var snapshot: OfflineCacheClient
    var makeSnapshotClient: @Sendable (OfflineCacheKey) -> OfflineCacheClient
    var rebuildRepositoriesOnVersionUpdate: Bool = false

    func isValid(for server: ServerConfig) -> Bool {
        server.connectionFingerprint == fingerprint
    }

    func apply(to values: inout DependencyValues) {
        values.transmissionClient = dependencies.transmissionClient
        values.torrentRepository = dependencies.torrentRepository
        values.sessionRepository = dependencies.sessionRepository
    }

    func updatingRPCVersion(_ rpcVersion: Int?) -> ServerConnectionEnvironment {
        var copy = self
        copy.cacheKey = cacheKey.withRPCVersion(rpcVersion)
        copy.snapshot = makeSnapshotClient(copy.cacheKey)
        if rebuildRepositoriesOnVersionUpdate {
            let mapper = TransmissionDomainMapper()
            copy.dependencies = .init(
                transmissionClient: dependencies.transmissionClient,
                torrentRepository: TorrentRepository.live(
                    transmissionClient: dependencies.transmissionClient,
                    mapper: mapper,
                    snapshot: copy.snapshot
                ),
                sessionRepository: SessionRepository.live(
                    transmissionClient: dependencies.transmissionClient,
                    mapper: mapper,
                    snapshot: copy.snapshot
                )
            )
        }
        return copy
    }
}

extension ServerConnectionEnvironment: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.serverID == rhs.serverID
            && lhs.fingerprint == rhs.fingerprint
            && lhs.cacheKey == rhs.cacheKey
            && lhs.rebuildRepositoriesOnVersionUpdate
                == rhs.rebuildRepositoriesOnVersionUpdate
    }
}

// MARK: - Factory

struct ServerConnectionEnvironmentFactory: Sendable {
    var make: @Sendable (_ server: ServerConfig) async throws -> ServerConnectionEnvironment

    func callAsFunction(_ server: ServerConfig) async throws -> ServerConnectionEnvironment {
        try await make(server)
    }
}

extension ServerConnectionEnvironmentFactory: DependencyKey {
    static var liveValue: Self {
        @Dependency(\.credentialsRepository) var credentialsRepository
        @Dependency(\.appClock) var appClock
        @Dependency(\.transmissionTrustPromptCenter) var trustPromptCenter
        @Dependency(\.appLogger) var appLogger
        @Dependency(\.offlineCacheRepository) var offlineCacheRepository

        return Self { server in
            let password = try await loadPassword(
                server: server,
                credentialsRepository: credentialsRepository
            )
            let credentialsFingerprint = OfflineCacheKey.credentialsFingerprint(
                credentialsKey: server.credentialsKey,
                password: password
            )
            let cacheKey = OfflineCacheKey.make(
                server: server,
                credentialsFingerprint: credentialsFingerprint,
                rpcVersion: nil
            )
            let snapshotClient = offlineCacheRepository.client(cacheKey)
            let mapper = TransmissionDomainMapper()

            let loggerContext = TransmissionLogContext(
                serverID: server.id,
                host: server.connection.host,
                path: server.connection.path
            )
            let safeLogger = DefaultTransmissionLogger(
                appLogger: appLogger.withCategory("transmission"),
                baseContext: loggerContext
            )
            let config = server.makeTransmissionClientConfig(
                password: password,
                network: .default,
                logger: safeLogger
            )
            let client = TransmissionClient(
                config: config,
                clock: appClock.clock(),
                appLogger: appLogger.withCategory("transmission"),
                baseLogContext: loggerContext
            )
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())

            let dependency = TransmissionClientDependency.live(client: client)
            let torrentRepository = TorrentRepository.live(
                transmissionClient: dependency,
                mapper: mapper,
                snapshot: snapshotClient
            )
            let sessionRepository = SessionRepository.live(
                transmissionClient: dependency,
                mapper: mapper,
                snapshot: snapshotClient
            )
            return ServerConnectionEnvironment(
                serverID: server.id,
                fingerprint: server.connectionFingerprint,
                dependencies: .init(
                    transmissionClient: dependency,
                    torrentRepository: torrentRepository,
                    sessionRepository: sessionRepository
                ),
                cacheKey: cacheKey,
                snapshot: snapshotClient,
                makeSnapshotClient: offlineCacheRepository.client,
                rebuildRepositoriesOnVersionUpdate: true
            )
        }
    }

    static var previewValue: Self {
        Self { server in
            ServerConnectionEnvironment.preview(server: server)
        }
    }

    static var testValue: Self {
        Self { _ in
            throw ServerConnectionEnvironmentFactoryError.notConfigured("testValue")
        }
    }

    private static func loadPassword(
        server: ServerConfig,
        credentialsRepository: CredentialsRepository
    ) async throws -> String? {
        guard let credentialsKey = server.credentialsKey else {
            return nil
        }
        guard let credentials = try await credentialsRepository.load(key: credentialsKey) else {
            throw ServerConnectionEnvironmentFactoryError.missingCredentials
        }
        return credentials.password
    }
}

extension DependencyValues {
    var serverConnectionEnvironmentFactory: ServerConnectionEnvironmentFactory {
        get { self[ServerConnectionEnvironmentFactory.self] }
        set { self[ServerConnectionEnvironmentFactory.self] = newValue }
    }
}

enum ServerConnectionEnvironmentFactoryError: Error, Equatable, LocalizedError {
    case missingCredentials
    case notConfigured(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Не удалось найти пароль для выбранного сервера."
        case .notConfigured(let context):
            return "ServerConnectionEnvironmentFactory (\(context)) не настроена."
        }
    }
}

extension ServerConnectionEnvironmentFactory {
    static let unimplemented: Self = Self { _ in
        throw ServerConnectionEnvironmentFactoryError.notConfigured("unimplemented")
    }

    static func mock(
        environment: ServerConnectionEnvironment
    ) -> Self {
        Self { _ in environment }
    }
}

extension ServerConnectionEnvironment {
    static func preview(server: ServerConfig) -> ServerConnectionEnvironment {
        var client = TransmissionClientDependency.placeholder
        client.performHandshake = {
            TransmissionHandshakeResult(
                sessionID: "preview-session",
                rpcVersion: 17,
                minimumSupportedRpcVersion: 14,
                serverVersionDescription: "Transmission Preview",
                isCompatible: true
            )
        }
        let offlineCache = OfflineCacheRepository.inMemory()
        let cacheKey = OfflineCacheKey.make(
            server: server,
            credentialsFingerprint: OfflineCacheKey.credentialsFingerprint(
                credentialsKey: server.credentialsKey,
                password: nil
            ),
            rpcVersion: nil
        )
        return ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: client,
                torrentRepository: .previewValue,
                sessionRepository: .placeholder
            ),
            cacheKey: cacheKey,
            snapshot: offlineCache.client(cacheKey),
            makeSnapshotClient: offlineCache.client
        )
    }

    static func testEnvironment(
        server: ServerConfig,
        transmissionClient: TransmissionClientDependency = .placeholder,
        torrentRepository: TorrentRepository = .testValue,
        sessionRepository: SessionRepository = .placeholder
    ) -> ServerConnectionEnvironment {
        let offlineCache = OfflineCacheRepository.inMemory()
        let cacheKey = OfflineCacheKey.make(
            server: server,
            credentialsFingerprint: OfflineCacheKey.credentialsFingerprint(
                credentialsKey: server.credentialsKey,
                password: nil
            ),
            rpcVersion: nil
        )
        return ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: transmissionClient,
                torrentRepository: torrentRepository,
                sessionRepository: sessionRepository
            ),
            cacheKey: cacheKey,
            snapshot: offlineCache.client(cacheKey),
            makeSnapshotClient: offlineCache.client
        )
    }

    static func testEnvironment(
        server: ServerConfig,
        handshake: TransmissionHandshakeResult,
        torrentRepository: TorrentRepository = .testValue,
        sessionRepository: SessionRepository = .placeholder
    ) -> ServerConnectionEnvironment {
        var client = TransmissionClientDependency.placeholder
        client.performHandshake = {
            handshake
        }
        return testEnvironment(
            server: server,
            transmissionClient: client,
            torrentRepository: torrentRepository,
            sessionRepository: sessionRepository
        )
    }
}
