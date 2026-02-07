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
        let stream = await center.observe()
        var iterator = stream.makeAsyncIterator()

        let decisionTask = Task { await handler(challenge) }
        let prompt = try #require(await iterator.next())

        #expect(prompt.challenge == challenge)

        prompt.resolve(with: .trustPermanently)
        let decision = await decisionTask.value

        #expect(decision == .trustPermanently)
    }

    @Test("observe() is broadcast: несколько подписчиков получают один и тот же prompt")
    func observeBroadcastsPromptsToMultipleSubscribers() async throws {
        let center = TransmissionTrustPromptCenter()
        let handler = center.makeHandler()

        let stream1 = await center.observe()
        let stream2 = await center.observe()

        var it1 = stream1.makeAsyncIterator()
        var it2 = stream2.makeAsyncIterator()

        let challenge = makeChallenge(host: "broadcast.local")
        let decisionTask = Task { await handler(challenge) }

        let prompt1 = try #require(await it1.next())
        let prompt2 = try #require(await it2.next())

        #expect(prompt1.challenge == challenge)
        #expect(prompt2.challenge == challenge)

        // Resolving multiple times must not crash (Only the first should win).
        prompt1.resolve(with: .trustPermanently)
        prompt2.resolve(with: .deny)

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
