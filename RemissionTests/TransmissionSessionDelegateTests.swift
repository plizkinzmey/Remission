import Foundation
import Security
import Testing

@testable import Remission

// Helpers to mock URLSession objects
class MockProtectionSpace: URLProtectionSpace, @unchecked Sendable {
    let _serverTrust: SecTrust?

    init(serverTrust: SecTrust) {
        self._serverTrust = serverTrust
        super.init(
            host: "localhost", port: 443, protocol: "https", realm: nil,
            authenticationMethod: NSURLAuthenticationMethodServerTrust)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var serverTrust: SecTrust? { return _serverTrust }
}

final class MockChallengeSender: NSObject, URLAuthenticationChallengeSender, @unchecked Sendable {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
    func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}
    func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}

@Suite("Transmission Session Delegate Tests")
struct TransmissionSessionDelegateTests {

    @Test
    func didReceiveChallenge_ServerTrust_EvaluatesTrust() async throws {
        let (trust, _) = try CertificateHelpers.makeSelfSignedTrust()
        let store = TransmissionTrustStore.inMemory()
        let identity = TransmissionServerTrustIdentity(host: "localhost", port: 443, isSecure: true)

        // Setup evaluator to approve trust
        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in
                return .trustPermanently
            }
        )

        let delegate = TransmissionSessionDelegate(trustEvaluator: evaluator)

        let protectionSpace = MockProtectionSpace(serverTrust: trust)
        let sender = MockChallengeSender()
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0,
            failureResponse: nil, error: nil, sender: sender)

        // Using continuation to wait for async completion handler
        await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                didReceive: challenge
            ) { disposition, credential in
                // Expect useCredential because evaluator approved it (trustPermanently -> save -> useCredential)
                #expect(disposition == .useCredential)
                #expect(credential != nil)
                continuation.resume()
            }
        }
    }

    @Test
    func didReceiveChallenge_OtherMethod_PerformsDefaultHandling() async throws {
        let store = TransmissionTrustStore.inMemory()
        let identity = TransmissionServerTrustIdentity(host: "localhost", port: 443, isSecure: true)

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in .deny }
        )

        let delegate = TransmissionSessionDelegate(trustEvaluator: evaluator)

        // Basic auth challenge
        let protectionSpace = URLProtectionSpace(
            host: "localhost", port: 443, protocol: "https", realm: nil,
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        let sender = MockChallengeSender()
        let challenge = URLAuthenticationChallenge(
            protectionSpace: protectionSpace, proposedCredential: nil, previousFailureCount: 0,
            failureResponse: nil, error: nil, sender: sender)

        await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                didReceive: challenge
            ) { disposition, credential in
                #expect(disposition == .performDefaultHandling)
                #expect(credential == nil)
                continuation.resume()
            }
        }
    }
}
