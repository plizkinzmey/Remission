import Foundation
import Testing

@testable import Remission

@Suite("TransmissionTrustPromptCenter Tests")
struct TransmissionTrustPromptCenterTests {
    @Test("makeHandler emits prompt and resumes with decision")
    func testPromptEmissionAndResolution() async {
        let center = TransmissionTrustPromptCenter()
        let handler = center.makeHandler()

        let identity = TransmissionServerTrustIdentity(
            host: "example.com", port: 443, isSecure: true)
        let certificateInfo = TransmissionCertificateInfo(
            commonName: "example.com",
            organization: "Remission",
            validFrom: Date(),
            validUntil: Date().addingTimeInterval(3600),
            sha256Fingerprint: Data(repeating: 0xAA, count: 32)
        )
        let challenge = TransmissionTrustChallenge(
            identity: identity,
            reason: .untrustedCertificate,
            certificate: certificateInfo
        )

        async let decision = handler(challenge)

        var iterator = center.prompts.makeAsyncIterator()
        let prompt = await iterator.next()

        #expect(prompt?.challenge == challenge)
        prompt?.resolve(with: .trustPermanently)

        let resolvedDecision = await decision
        #expect(resolvedDecision == .trustPermanently)
    }
}
