import Foundation

/// Состояние проверки соединения с сервером.
enum ServerConnectionStatus: Equatable, Sendable {
    case idle
    case testing
    case success(TransmissionHandshakeResult)
    case failed(String)
}

/// Контекст данных для выполнения проверки или сохранения сервера.
struct ServerSubmissionContext: Equatable, Sendable {
    var server: ServerConfig
    var password: String?
}

/// Результат проверки соединения.
enum ServerConnectionTestResult: Equatable, Sendable {
    case success(TransmissionHandshakeResult)
    case failure(String)
}
