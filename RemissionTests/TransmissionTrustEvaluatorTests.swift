import Foundation
import Security
import Testing

@testable import Remission

// A simple thread-safe state container for testing
actor TestCallbackState {
    var wasCalled = false
    func setCalled() { wasCalled = true }
    func checkCalled() -> Bool { wasCalled }
}

@Suite("Transmission Trust Evaluator Tests")
struct TransmissionTrustEvaluatorTests {

    @Test
    func evaluateUntrustedCallsDecisionHandler() async throws {
        let (trust, _) = try CertificateHelpers.makeSelfSignedTrust()
        let store = TransmissionTrustStore.inMemory()
        let identity = TransmissionServerTrustIdentity(host: "localhost", port: 443, isSecure: true)

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { challenge in
                #expect(challenge.reason == .untrustedCertificate)
                return .deny
            }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)

        if case .cancel(let error) = outcome {
            if case .userDeclined = error {
                // Success
            } else {
                Issue.record("Expected userDeclined error, got \(error)")
            }
        } else {
            Issue.record("Expected cancel outcome, got \(outcome)")
        }
    }

    @Test
    func evaluateUntrustedApprovedSavesFingerprint() async throws {
        let (trust, fingerprint) = try CertificateHelpers.makeSelfSignedTrust()
        let store = TransmissionTrustStore.inMemory()
        let identity = TransmissionServerTrustIdentity(host: "localhost", port: 443, isSecure: true)

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in
                return .trustPermanently
            }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)

        if case .useCredential = outcome {
            // Verify fingerprint is saved
            let saved = try store.loadFingerprint(for: identity)
            #expect(saved == fingerprint)
        } else {
            Issue.record("Expected useCredential outcome, got \(outcome)")
        }
    }

    @Test
    func evaluateKnownFingerprintSkipsHandler() async throws {
        let (trust, fingerprint) = try CertificateHelpers.makeSelfSignedTrust()
        let store = TransmissionTrustStore.inMemory()
        let identity = TransmissionServerTrustIdentity(host: "localhost", port: 443, isSecure: true)

        try store.saveFingerprint(fingerprint, for: identity, metadata: nil)

        let state = TestCallbackState()
        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in
                await state.setCalled()
                return .deny
            }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)

        let wasCalled = await state.checkCalled()
        #expect(!wasCalled)

        if case .useCredential = outcome {
            // Success
        } else {
            Issue.record("Expected useCredential outcome, got \(outcome)")
        }
    }

    @Test
    func evaluateFingerprintMismatchTriggersMismatchReason() async throws {
        let (trust, _) = try CertificateHelpers.makeSelfSignedTrust()
        let store = TransmissionTrustStore.inMemory()
        let identity = TransmissionServerTrustIdentity(host: "localhost", port: 443, isSecure: true)

        // Save a fake different fingerprint
        let fakeFingerprint = Data(repeating: 0xAA, count: 32)
        try store.saveFingerprint(fakeFingerprint, for: identity, metadata: nil)

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { challenge in
                if case .fingerprintMismatch = challenge.reason {
                    // Success
                } else {
                    Issue.record("Expected fingerprintMismatch reason, got \(challenge.reason)")
                }
                return .deny
            }
        )

        _ = await evaluator.evaluate(serverTrust: trust)

        // Verify old fingerprint is deleted (logic in handleUntrustedCertificate)
        let saved = try store.loadFingerprint(for: identity)
        #expect(saved == nil)
    }
}
