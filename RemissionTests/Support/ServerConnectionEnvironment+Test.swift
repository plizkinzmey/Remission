import Foundation

@testable import Remission

extension ServerConnectionEnvironment {
    static func testEnvironment(
        server: ServerConfig,
        handshake: TransmissionHandshakeResult
    ) -> ServerConnectionEnvironment {
        var client = TransmissionClientDependency.placeholder
        client.performHandshake = { handshake }
        return ServerConnectionEnvironment(
            serverID: server.id,
            fingerprint: server.connectionFingerprint,
            dependencies: .init(
                transmissionClient: client,
                torrentRepository: .placeholder,
                sessionRepository: .placeholder
            )
        )
    }
}
