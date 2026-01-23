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

/// Вспомогательные методы для работы с ошибками соединения.
enum ServerConnectionErrorHelper {
    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let rawMessage =
            nsError.localizedDescription.isEmpty
            ? String(describing: error)
            : nsError.localizedDescription
        return localizeConnectionMessage(rawMessage)
    }

    static func localizeConnectionMessage(_ message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("timeout") || lowercased.contains("timed out") {
            return L10n.tr("onboarding.connection.timeout")
        }
        if lowercased.contains("cancelled") || lowercased.contains("canceled") {
            return L10n.tr("onboarding.connection.cancelled")
        }
        return message
    }
}
