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

    func isValid(for server: ServerConfig) -> Bool {
        server.connectionFingerprint == fingerprint
    }

    func apply(to values: inout DependencyValues) {
        values.transmissionClient = dependencies.transmissionClient
        values.torrentRepository = dependencies.torrentRepository
        values.sessionRepository = dependencies.sessionRepository
    }
}

extension ServerConnectionEnvironment: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.serverID == rhs.serverID && lhs.fingerprint == rhs.fingerprint
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

        return Self { server in
            let password = try await loadPassword(
                server: server,
                credentialsRepository: credentialsRepository
            )

            let config = server.makeTransmissionClientConfig(
                password: password,
                network: .default,
                logger: DefaultTransmissionLogger()
            )
            let client = TransmissionClient(config: config, clock: appClock.clock())
            client.setTrustDecisionHandler(trustPromptCenter.makeHandler())

            let dependency = TransmissionClientDependency.live(client: client)
            let torrentRepository = TorrentRepository.live(transmissionClient: dependency)
            let sessionRepository = SessionRepository.live(
                transmissionClient: dependency,
                mapper: TransmissionDomainMapper()
            )
            return ServerConnectionEnvironment(
                serverID: server.id,
                fingerprint: server.connectionFingerprint,
                dependencies: .init(
                    transmissionClient: dependency,
                    torrentRepository: torrentRepository,
                    sessionRepository: sessionRepository
                )
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
        return ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: client,
                torrentRepository: .previewValue,
                sessionRepository: .placeholder
            )
        )
    }

    static func testEnvironment(
        server: ServerConfig,
        transmissionClient: TransmissionClientDependency = .placeholder,
        torrentRepository: TorrentRepository = .testValue,
        sessionRepository: SessionRepository = .placeholder
    ) -> ServerConnectionEnvironment {
        ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: transmissionClient,
                torrentRepository: torrentRepository,
                sessionRepository: sessionRepository
            )
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

extension ServerConfig {
    var connectionFingerprint: String {
        httpWarningFingerprint
    }
}
