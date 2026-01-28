import Foundation
import Testing

@testable import Remission

@Suite("Transmission Server Credentials Tests")
struct TransmissionServerCredentialsTests {
    // Проверяет формирование accountIdentifier для HTTP и HTTPS.
    @Test
    func accountIdentifierIncludesSchemeHostPortAndUsername() {
        let httpKey = TransmissionServerCredentialsKey(
            host: "nas.local",
            port: 9091,
            isSecure: false,
            username: "admin"
        )
        #expect(httpKey.accountIdentifier == "admin/nas.local:9091/http")

        let httpsKey = TransmissionServerCredentialsKey(
            host: "seedbox.io",
            port: 443,
            isSecure: true,
            username: "seed"
        )
        #expect(httpsKey.accountIdentifier == "seed/seedbox.io:443/https")
    }

    // Проверяет, что модель credentials хранит ключ и пароль без изменений.
    @Test
    func credentialsStoreKeyAndPassword() {
        let key = TransmissionServerCredentialsKey(
            host: "host",
            port: 1,
            isSecure: true,
            username: "user"
        )
        let credentials = TransmissionServerCredentials(key: key, password: "pass")

        #expect(credentials.key == key)
        #expect(credentials.password == "pass")
    }
}
