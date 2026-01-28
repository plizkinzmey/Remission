import Foundation
import Testing

@testable import Remission

@Suite("Transmission Trust Models Tests")
struct TransmissionTrustModelsTests {
    // Проверяет canonicalIdentifier: схема + lowercase host + порт.
    @Test
    func canonicalIdentifierNormalizesHostAndScheme() {
        let identity = TransmissionServerTrustIdentity(host: "NAS.LOCAL", port: 443, isSecure: true)
        #expect(identity.canonicalIdentifier == "https://nas.local:443")
    }

    // Проверяет fingerprintHexString и устойчивое сравнение сертификатов.
    @Test
    func certificateFingerprintAndEqualityIgnoreDates() {
        let fingerprint = Data([0xAA, 0xBB, 0x01])
        let cert1 = TransmissionCertificateInfo(
            commonName: "seedbox",
            organization: "org",
            validFrom: Date(timeIntervalSince1970: 0),
            validUntil: Date(timeIntervalSince1970: 10),
            sha256Fingerprint: fingerprint
        )
        let cert2 = TransmissionCertificateInfo(
            commonName: "seedbox",
            organization: "org",
            validFrom: Date(timeIntervalSince1970: 100),
            validUntil: Date(timeIntervalSince1970: 200),
            sha256Fingerprint: fingerprint
        )

        #expect(cert1.fingerprintHexString == "aabb01")
        #expect(cert1 == cert2)
    }
}
