import Foundation
import Security

@testable import Remission

enum CertificateHelpers {
    enum Error: Swift.Error {
        case invalidCertificateData
        case certificateCreationFailure
        case trustCreationFailure
    }

    static func makeSelfSignedTrust() throws -> (SecTrust, Data) {
        let base64 = """
            MIIDCTCCAfGgAwIBAgIUfC1E3uYrPn6K3Et6YbWaQXDP6KwwDQYJKoZIhvcNAQEL
            BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI2MDEyNzIxMDgyN1oXDTI3MDEy
            NzIxMDgyN1owFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEF
            AAOCAQ8AMIIBCgKCAQEAysoK3DQqYQHrT5XSnJneFibDwwAb9iDYjqKYwiqXSS3e
            gw5DxfjN3dsb0ansg4ZbttEi9+xZcG9hBNJNtWKs9PVAfp80urkwBqRfMwNTtYiE
            z3JUBhNZH0ssQw+/WdiQ54iwYT8TMUyw1OBfIxH70yVvbKFL39MzntlC/iPSINsd
            gANm8pCex7AF+5lMYzlYmezRID7fT1EiXOzMLux4LDa2GxbbB+3OGIUaMswDESlK
            AIKM1vGhPrfjFRZEtE8DgD5fonFiqHpCeA0S5wX3AL0gNUIYpSyQLNoCnD9pDxXJ
            1/yDxi+CByzZxzZe/e0AEtjezRAC1CFrvpE4zVUPNQIDAQABo1MwUTAdBgNVHQ4E
            FgQUoqp4OYRuzrJIRUBgHZwbTp8yB4wwHwYDVR0jBBgwFoAUoqp4OYRuzrJIRUBg
            HZwbTp8yB4wwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAnBLF
            ntgPwhmYEFR1xEYwa4+tpgriRilSBqd5ydS8vb0n9fp4yKnhdAk+qxbp9/Vo6GML
            BWX95H7UYE1huBJyKKDbYCbcCe41blC9UIH4X8vbuYBrgQgZlNZWHWaDllIH2vak
            lGBJaqbixUuckxuv/JMbRiWLxYpgsQglcoTsYHvXHzVQxqEEtjn6L342X5ln3jdx
            IGgxl1ETWVZtuYCdsGr7uNlbeWi/iulzY4eUyY5Uq1iIxg5Q5YTlGUxVZowqF3Mv
            94C4eA+mQdGSsCTJSlmlfrPTpWIxQZTA69K80XgFBWfBAkg2Vyst5IDMm+tIVYop
            /aLi0C4h0/8XcMgoWQ==
            """

        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            throw Error.invalidCertificateData
        }

        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else {
            throw Error.certificateCreationFailure
        }

        var trust: SecTrust?
        let policy = SecPolicyCreateSSL(true, "localhost" as CFString)
        let status = SecTrustCreateWithCertificates(cert, policy, &trust)

        guard status == errSecSuccess, let createdTrust = trust else {
            throw Error.trustCreationFailure
        }

        let fingerprint = try TransmissionCertificateFingerprint.fingerprintSHA256(
            for: createdTrust)

        return (createdTrust, fingerprint)
    }
}
