import Foundation
import Testing

@testable import Remission

@Suite("Server Config Tests")
struct ServerConfigTests {
    // Проверяет, что makeFingerprint нормализует регистр.
    @Test
    func fingerprintIsLowercased() {
        let fingerprint = ServerConfig.makeFingerprint(
            host: "NAS.LOCAL",
            port: 9091,
            username: "Admin"
        )
        #expect(fingerprint == "nas.local:9091:admin")
    }

    // Проверяет построение baseURL и displayAddress для HTTP.
    @Test
    func httpBaseURLAndDisplayAddress() throws {
        var server = ServerConfig.previewLocalHTTP
        server.connection.path = "rpc"

        #expect(server.isSecure == false)
        #expect(server.usesInsecureTransport)
        let url = try server.makeBaseURL()
        #expect(url.absoluteString.contains("http://nas.local:9091/"))
        #expect(server.displayAddress == "http://nas.local:9091")
    }

    @Test
    func invalidHostThrows() {
        var server = ServerConfig.previewLocalHTTP
        server.connection.host = ""
        #expect(throws: ServerConfig.ServerConfigError.self) {
            _ = try server.makeBaseURL()
        }
    }

    // Проверяет, что credentialsKey формируется при наличии username.
    @Test
    func credentialsKeyExistsWhenAuthenticationIsPresent() {
        let server = ServerConfig.previewSecureSeedbox
        let key = server.credentialsKey
        #expect(key != nil)
        #expect(key?.host == server.connection.host)
        #expect(key?.port == server.connection.port)
        #expect(key?.isSecure == true)
        #expect(key?.username == "seeduser")
    }

    // Проверяет стабильность connectionFingerprint как маркера переподключения.
    @Test
    func connectionFingerprintContainsCoreConnectionFields() {
        let server = ServerConfig.previewSecureSeedbox
        let fingerprint = server.connectionFingerprint
        #expect(fingerprint.contains(server.connection.host))
        #expect(fingerprint.contains(":\(server.connection.port):"))
        #expect(fingerprint.contains(server.connection.path))
        #expect(fingerprint.contains("true"))
        #expect(fingerprint.contains("seeduser"))
    }
}
