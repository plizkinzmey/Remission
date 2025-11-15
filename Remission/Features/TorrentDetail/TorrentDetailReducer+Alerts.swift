import ComposableArchitecture
import Foundation

extension AlertState where Action == TorrentDetailReducer.AlertAction {
    static func info(message: String) -> AlertState {
        AlertState {
            TextState("Готово")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("OK")
            }
        } message: {
            TextState(message)
        }
    }

    static func error(message: String) -> AlertState {
        AlertState {
            TextState("Ошибка")
        } actions: {
            ButtonState(action: .dismiss) {
                TextState("Понятно")
            }
        } message: {
            TextState(message)
        }
    }

    static func connectionMissing() -> AlertState {
        .error(message: "Нет подключения к серверу")
    }
}

extension ConfirmationDialogState
where Action == TorrentDetailReducer.RemoveConfirmationAction {
    static func removeTorrent(name: String) -> ConfirmationDialogState {
        ConfirmationDialogState {
            TextState("Удалить торрент «\(name.isEmpty ? "Без названия" : name)»?")
        } actions: {
            ButtonState(role: .destructive, action: .deleteTorrentOnly) {
                TextState("Удалить торрент")
            }
            ButtonState(role: .destructive, action: .deleteWithData) {
                TextState("Удалить с данными")
            }
            ButtonState(role: .cancel, action: .cancel) {
                TextState("Отмена")
            }
        }
    }
}

extension APIError {
    var userFriendlyMessage: String {
        switch self {
        case .networkUnavailable:
            return "Сеть недоступна"
        case .unauthorized:
            return "Ошибка аутентификации"
        case .sessionConflict:
            return "Конфликт сессии"
        case .tlsTrustDeclined:
            return "Подключение отклонено: сертификат не доверен"
        case .tlsEvaluationFailed(let details):
            return "Ошибка проверки сертификата: \(details)"
        case .versionUnsupported(let version):
            return "Версия Transmission не поддерживается (\(version))"
        case .decodingFailed:
            return "Ошибка парсирования ответа"
        case .unknown(let details):
            return "Ошибка: \(details)"
        }
    }
}
