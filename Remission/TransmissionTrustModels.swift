import Foundation

/// Идентификатор сервера для проверки TLS-доверия.
/// Используется для привязки отпечатка сертификата к конкретному endpoint.
public struct TransmissionServerTrustIdentity: Equatable, Hashable, Sendable {
    public var host: String
    public var port: Int
    public var isSecure: Bool

    public init(host: String, port: Int, isSecure: Bool) {
        self.host = host
        self.port = port
        self.isSecure = isSecure
    }

    /// Канонический идентификатор `scheme://host:port`.
    public var canonicalIdentifier: String {
        let scheme: String = isSecure ? "https" : "http"
        return "\(scheme)://\(host.lowercased()):\(port)"
    }
}

/// Краткая информация о сертификате, используемая для отображения пользователю.
public struct TransmissionCertificateInfo: Equatable, Sendable {
    public var commonName: String?
    public var organization: String?
    public var validFrom: Date?
    public var validUntil: Date?
    public var sha256Fingerprint: Data

    public init(
        commonName: String?,
        organization: String?,
        validFrom: Date?,
        validUntil: Date?,
        sha256Fingerprint: Data
    ) {
        self.commonName = commonName
        self.organization = organization
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.sha256Fingerprint = sha256Fingerprint
    }

    /// Отпечаток SHA-256 в формате HEX (удобен для UI).
    public var fingerprintHexString: String {
        sha256Fingerprint.map { String(format: "%02hhx", $0) }.joined()
    }
}

/// Делает сравнение сертификатов устойчивым к незначительным расхождениям дат.
/// Для целей UX и тестов достаточно сравнивать стабильные поля: имя/организацию и отпечаток.
public func == (lhs: TransmissionCertificateInfo, rhs: TransmissionCertificateInfo) -> Bool {
    lhs.commonName == rhs.commonName
        && lhs.organization == rhs.organization
        && lhs.sha256Fingerprint == rhs.sha256Fingerprint
}

/// Причина, по которой требуется решение пользователя относительно доверия сертификату.
public enum TransmissionTrustChallengeReason: Equatable, Sendable {
    /// Сертификат не доверен системой и отпечаток отсутствует в локальном хранилище.
    case untrustedCertificate

    /// Отпечаток изменился по сравнению с сохранённым значением.
    case fingerprintMismatch(previousFingerprint: Data)
}

/// Событие, запрашивающее решение пользователя о доверии сертификату.
public struct TransmissionTrustChallenge: Equatable, Sendable {
    public var identity: TransmissionServerTrustIdentity
    public var reason: TransmissionTrustChallengeReason
    public var certificate: TransmissionCertificateInfo

    public init(
        identity: TransmissionServerTrustIdentity,
        reason: TransmissionTrustChallengeReason,
        certificate: TransmissionCertificateInfo
    ) {
        self.identity = identity
        self.reason = reason
        self.certificate = certificate
    }
}

/// Решение, принимаемое пользователем при показе диалога доверия.
public enum TransmissionTrustDecision: Equatable, Sendable {
    /// Пользователь доверяет сертификату и разрешает сохранить отпечаток.
    case trustPermanently
    /// Пользователь отказывает в доверии (соединение должно быть отменено).
    case deny
}

/// Ошибка, возникающая при обработке доверия сертификату.
public enum TransmissionTrustError: Error, Equatable, Sendable {
    /// Пользователь отказался доверять сертификату.
    case userDeclined(TransmissionTrustChallenge)
    /// Середина процесса оценки доверия завершилась ошибкой.
    case evaluationFailed(String)
    /// Запрос доверия не может быть обработан (например, отсутствует хендлер).
    case handlerUnavailable(TransmissionTrustChallenge)
}

/// Обработчик запросов доверия. Возвращает решение пользователя.
public typealias TransmissionTrustDecisionHandler =
    @Sendable (TransmissionTrustChallenge) async -> TransmissionTrustDecision
