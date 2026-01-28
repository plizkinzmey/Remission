import Foundation
import Testing

@testable import Remission

@Suite("TransmissionTrustPromptCenter")
struct TransmissionTrustPromptCenterTests {
    @Test("makeHandler публикует prompt и возвращает принятое решение")
    func handlerPublishesPromptAndReturnsResolution() async throws {
        // Этот тест покрывает полный цикл:
        // evaluator вызывает handler -> UI получает prompt -> пользователь резолвит -> handler получает решение.
        let center = TransmissionTrustPromptCenter()
        let handler = center.makeHandler()

        let challenge = makeChallenge(host: "seedbox.local")
        let decisionTask = Task { await handler(challenge) }

        var iterator = center.prompts.makeAsyncIterator()
        let prompt = try #require(await iterator.next())

        #expect(prompt.challenge == challenge)

        prompt.resolve(with: .trustPermanently)
        let decision = await decisionTask.value

        #expect(decision == .trustPermanently)
    }
}

private func makeChallenge(host: String) -> TransmissionTrustChallenge {
    let identity = TransmissionServerTrustIdentity(host: host, port: 443, isSecure: true)
    let certificate = TransmissionCertificateInfo(
        commonName: host,
        organization: "Remission",
        validFrom: Date(timeIntervalSince1970: 0),
        validUntil: Date(timeIntervalSince1970: 60 * 60 * 24),
        sha256Fingerprint: Data([0xAA, 0xBB, 0xCC])
    )
    return TransmissionTrustChallenge(
        identity: identity,
        reason: .untrustedCertificate,
        certificate: certificate
    )
}
