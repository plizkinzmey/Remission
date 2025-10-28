import Foundation

/// Параметры подключения сервера Transmission, используемые для идентификации записи в Keychain.
struct TransmissionServerCredentialsKey: Equatable, Hashable, Sendable {
    var host: String
    var port: Int
    var isSecure: Bool
    var username: String

    /// Служебный идентификатор аккаунта для Keychain (`username/host:port/scheme`).
    var accountIdentifier: String {
        let scheme: String = isSecure ? "https" : "http"
        return "\(username)/\(host):\(port)/\(scheme)"
    }
}

/// Секреты, сохраненные в Keychain для конкретного сервера Transmission.
struct TransmissionServerCredentials: Equatable, Sendable {
    var key: TransmissionServerCredentialsKey
    var password: String
}
