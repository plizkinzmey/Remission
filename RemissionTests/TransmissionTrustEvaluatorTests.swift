import Foundation
import Security
import Testing

@testable import Remission

@Suite("TransmissionTrustEvaluator Tests")
struct TransmissionTrustEvaluatorTests {
    private static let certificateBase64Segments: [String] = [
        "MIIC9jCCAd4CCQCM3wBzrmaggzANBgkqhkiG9w0BAQsFADA9MRowGAYDVQQDDBFt",
        "b2NrLnRyYW5zbWlzc2lvbjESMBAGA1UECgwJUmVtaXNzaW9uMQswCQYDVQQLDAJR",
        "QTAeFw0yNTEwMzAyMTQ2NDJaFw0yNjEwMzAyMTQ2NDJaMD0xGjAYBgNVBAMMEW1v",
        "Y2sudHJhbnNtaXNzaW9uMRIwEAYDVQQKDAlSZW1pc3Npb24xCzAJBgNVBAsMAlFB",
        "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsNjwib3BdAyhRjuF8LBr",
        "vsc9XMExddnjmx22C0A0cRrLGEW+cq/ekCSGfDEFFNhm7DAo3zZjYxJfWfzzGACL",
        "xDqK/5osr/+nUd12HTgzQwIW5rBVeBniVrcWvLt2jLcY0rsYxtt6xcLZf7NplCAt",
        "E43UkJESxEICKR1r40+eM6W5oGosVs3a6+sg++B9M+TrYpSYtG7OmH+9CWTaqOkn",
        "YIDsuqEbN9qQ8tvnakvoGutAybHYPiLGdHBKj01FFQLjGWZFsy7gRe6gy28lLv5S",
        "m7D41yxmhcJRmP5MukeJGBX2DBhlmh8wIisf+sYr3u7lvCjfTwhf1DguGpB8UIyd",
        "7QIDAQABMA0GCSqGSIb3DQEBCwUAA4IBAQCbHA5cYKs4eSH/nnXVDIuuLh+HEMuQ",
        "C687aFJekmrpBzb20zLxPGeKlY6bb72wLYsM1bjrovILL4ZgKqK01zgLm4hVYXdW",
        "KzgmMcz6pFxbItbpzVUZ6v/RYU8PqtR4FifFqXQ2cSmcCCS7L+9eaJ3CyzaJcPVw",
        "fkZ5WSKxiyaNFcGdCnVPhlR737SjKfvC5mjgMK0zq4g/HPLAJ6fW7/kdGE+KcHGL",
        "AyUVRjZeAkwSy/SAuSg56vA7EQ6njf83XSDNUD9qpFzn9QWpBZHvpWiHQgE7fUDF",
        "eiI6Fy/jw8GFYSE4akUovZ71ot+SfNynbPqGdgVytAC+w7d6xFcDADN0"
    ]
    private static let certificateBase64: String = certificateBase64Segments.joined()

    private func makeServerTrust() throws -> (SecTrust, SecCertificate) {
        guard let certificateData = Data(base64Encoded: Self.certificateBase64) else {
            throw TestError("Failed to decode certificate fixture")
        }
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw TestError("Unable to create certificate from data")
        }
        let policy = SecPolicyCreateSSL(true, "mock.transmission" as CFString)
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        guard status == errSecSuccess, let trust else {
            throw TestError("Failed to create SecTrust object, status \(status)")
        }
        return (trust, certificate)
    }

    private func makeIdentity() -> TransmissionServerTrustIdentity {
        TransmissionServerTrustIdentity(host: "mock.transmission", port: 443, isSecure: true)
    }

    @Test("Trusted certificate uses credential without prompting")
    func testEvaluatorUsesCredentialForTrustedCertificate() async throws {
        let (trust, certificate) = try makeServerTrust()
        let identity = makeIdentity()
        let store = TransmissionTrustStore.inMemory()

        SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
        SecTrustSetAnchorCertificatesOnly(trust, true)
        SecTrustSetPolicies(trust, SecPolicyCreateBasicX509())

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in .deny }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)

        guard case .useCredential = outcome else {
            #expect(Bool(false), "Expected useCredential outcome, got \(outcome)")
            return
        }
        let pendingError = await evaluator.consumePendingError()
        #expect(pendingError == nil)
    }

    @Test("Self-signed certificate is stored after user approval")
    func testEvaluatorStoresFingerprintAfterApproval() async throws {
        let (trust, _) = try makeServerTrust()
        let identity = makeIdentity()
        let store = TransmissionTrustStore.inMemory()

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in .trustPermanently }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)
        guard case .useCredential = outcome else {
            #expect(Bool(false), "Expected useCredential outcome, got \(outcome)")
            return
        }

        let fingerprint = try store.loadFingerprint(for: identity)
        #expect(fingerprint != nil)
        let pendingError = await evaluator.consumePendingError()
        #expect(pendingError == nil)
    }

    @Test("User denial produces cancel outcome and pending error")
    func testEvaluatorCancelsWhenUserDenies() async throws {
        let (trust, _) = try makeServerTrust()
        let identity = makeIdentity()
        let store = TransmissionTrustStore.inMemory()

        actor ChallengeRecorder {
            private var challenge: TransmissionTrustChallenge?
            func record(_ newValue: TransmissionTrustChallenge) {
                challenge = newValue
            }
            func value() -> TransmissionTrustChallenge? {
                challenge
            }
        }
        let recorder = ChallengeRecorder()

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { challenge in
                await recorder.record(challenge)
                return .deny
            }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)
        guard case .cancel = outcome else {
            #expect(Bool(false), "Expected cancel outcome, got \(outcome)")
            return
        }

        let pendingError = await evaluator.consumePendingError()
        guard case .userDeclined(let challenge)? = pendingError else {
            #expect(
                Bool(false),
                "Expected userDeclined pending error, got \(String(describing: pendingError))")
            return
        }
        #expect(challenge.reason == .untrustedCertificate)
        let recordedChallenge = await recorder.value()
        #expect(recordedChallenge?.reason == .untrustedCertificate)
        let stored = try store.loadFingerprint(for: identity)
        #expect(stored == nil)
    }

    @Test("Matching cached fingerprint skips user prompt")
    func testEvaluatorMatchesCachedFingerprint() async throws {
        let (trust, _) = try makeServerTrust()
        let identity = makeIdentity()
        let store = TransmissionTrustStore.inMemory()

        let fingerprint = try TransmissionCertificateFingerprint.fingerprintSHA256(for: trust)
        try store.saveFingerprint(fingerprint, for: identity, metadata: nil)

        actor InvocationFlag {
            private(set) var called: Bool = false
            func mark() { called = true }
            func value() -> Bool { called }
        }
        let flag = InvocationFlag()

        let evaluator = TransmissionTrustEvaluator(
            identity: identity,
            trustStore: store,
            decisionHandler: { _ in
                await flag.mark()
                return .deny
            }
        )

        let outcome = await evaluator.evaluate(serverTrust: trust)
        guard case .useCredential = outcome else {
            #expect(Bool(false), "Expected useCredential outcome, got \(outcome)")
            return
        }
        let wasCalled = await flag.value()
        #expect(wasCalled == false)
        let pendingError = await evaluator.consumePendingError()
        #expect(pendingError == nil)
    }
}

private struct TestError: Error, CustomStringConvertible {
    var description: String
    init(_ description: String) { self.description = description }
}
