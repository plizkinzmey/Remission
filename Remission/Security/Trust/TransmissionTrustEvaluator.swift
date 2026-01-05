import Foundation
import Security

/// Результат проверки доверия серверу.
enum TransmissionTrustEvaluationOutcome: Sendable {
    case useCredential(URLCredential)
    case performDefaultHandling
    case cancel(TransmissionTrustError)
}

/// Actor, отвечающий за проверку TLS доверия и взаимодействие с пользователем.
actor TransmissionTrustEvaluator {
    private let identity: TransmissionServerTrustIdentity
    private let trustStore: TransmissionTrustStore
    private var decisionHandler: TransmissionTrustDecisionHandler
    private var pendingError: TransmissionTrustError?

    init(
        identity: TransmissionServerTrustIdentity,
        trustStore: TransmissionTrustStore,
        decisionHandler: @escaping TransmissionTrustDecisionHandler
    ) {
        self.identity = identity
        self.trustStore = trustStore
        self.decisionHandler = decisionHandler
    }

    func updateDecisionHandler(_ handler: @escaping TransmissionTrustDecisionHandler) {
        decisionHandler = handler
    }

    func consumePendingError() -> TransmissionTrustError? {
        defer { pendingError = nil }
        return pendingError
    }

    func evaluate(serverTrust: SecTrust) async -> TransmissionTrustEvaluationOutcome {
        if SecTrustEvaluateWithError(serverTrust, nil) {
            return .useCredential(URLCredential(trust: serverTrust))
        }
        return await handleUntrustedCertificate(serverTrust)
    }

    private func handleUntrustedCertificate(
        _ serverTrust: SecTrust
    ) async -> TransmissionTrustEvaluationOutcome {
        do {
            let fingerprint: Data = try TransmissionCertificateFingerprint.fingerprintSHA256(
                for: serverTrust)
            let existingFingerprint: Data? = try trustStore.loadFingerprint(for: identity)

            if let existingFingerprint, existingFingerprint == fingerprint {
                return .useCredential(URLCredential(trust: serverTrust))
            }

            if existingFingerprint != nil {
                try trustStore.deleteFingerprint(for: identity)
            }

            let challenge: TransmissionTrustChallenge = try makeChallenge(
                serverTrust: serverTrust,
                fingerprint: fingerprint,
                existingFingerprint: existingFingerprint
            )

            let decision: TransmissionTrustDecision = await decisionHandler(challenge)
            return try applyDecision(
                decision,
                fingerprint: fingerprint,
                serverTrust: serverTrust,
                certificate: challenge.certificate,
                challenge: challenge
            )
        } catch let trustError as TransmissionTrustError {
            pendingError = trustError
            return .cancel(trustError)
        } catch {
            let message: String = error.localizedDescription
            let trustError: TransmissionTrustError = .evaluationFailed(message)
            pendingError = trustError
            return .cancel(trustError)
        }
    }

    private func makeChallenge(
        serverTrust: SecTrust,
        fingerprint: Data,
        existingFingerprint: Data?
    ) throws -> TransmissionTrustChallenge {
        let certificateInfo: TransmissionCertificateInfo =
            try makeCertificateInfo(from: serverTrust, fingerprint: fingerprint)

        let reason: TransmissionTrustChallengeReason =
            existingFingerprint.map {
                .fingerprintMismatch(previousFingerprint: $0)
            } ?? .untrustedCertificate

        return TransmissionTrustChallenge(
            identity: identity,
            reason: reason,
            certificate: certificateInfo
        )
    }

    private func applyDecision(
        _ decision: TransmissionTrustDecision,
        fingerprint: Data,
        serverTrust: SecTrust,
        certificate: TransmissionCertificateInfo,
        challenge: TransmissionTrustChallenge
    ) throws -> TransmissionTrustEvaluationOutcome {
        switch decision {
        case .trustPermanently:
            try trustStore.saveFingerprint(
                fingerprint,
                for: identity,
                metadata: certificate
            )
            return .useCredential(URLCredential(trust: serverTrust))

        case .deny:
            let error: TransmissionTrustError = .userDeclined(challenge)
            pendingError = error
            return .cancel(error)
        }
    }

    private func makeCertificateInfo(
        from trust: SecTrust,
        fingerprint: Data
    ) throws -> TransmissionCertificateInfo {
        let certificate: SecCertificate? = {
            guard
                let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
                let firstCertificate = certificates.first
            else {
                return nil
            }
            return firstCertificate
        }()

        let commonName: String? = {
            guard let certificate else { return nil }
            var cfName: CFString?
            let status: OSStatus = SecCertificateCopyCommonName(certificate, &cfName)
            guard status == errSecSuccess else { return nil }
            return cfName as String?
        }()

        let organization: String? = nil
        let validity: (Date?, Date?) = (nil, nil)

        return TransmissionCertificateInfo(
            commonName: commonName,
            organization: organization,
            validFrom: validity.0,
            validUntil: validity.1,
            sha256Fingerprint: fingerprint
        )
    }
}
