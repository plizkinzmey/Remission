import ComposableArchitecture
import Foundation

/// Фабрика для создания стандартных алертов и диалогов подтверждения.
enum AlertFactory {
    /// Создает алерт подтверждения удаления.
    static func deleteConfirmation<Action>(
        title: String,
        message: String,
        confirmAction: Action,
        cancelAction: Action
    ) -> AlertState<Action> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .destructive, action: confirmAction) {
                TextState(L10n.tr("common.delete"))
            }
            ButtonState(role: .cancel, action: cancelAction) {
                TextState(L10n.tr("common.cancel"))
            }
        } message: {
            TextState(message)
        }
    }

    /// Создает алерт с одной кнопкой "OK" (или кастомной).
    static func simpleAlert<Action>(
        title: String,
        message: String,
        buttonText: String = L10n.tr("common.ok"),
        action: Action
    ) -> AlertState<Action> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(role: .cancel, action: action) {
                TextState(buttonText)
            }
        } message: {
            TextState(message)
        }
    }

    /// Создает алерт подтверждения действия.
    static func confirmation<Action>(
        title: String,
        message: String,
        confirmText: String,
        confirmAction: Action,
        cancelAction: Action
    ) -> AlertState<Action> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(action: confirmAction) {
                TextState(confirmText)
            }
            ButtonState(role: .cancel, action: cancelAction) {
                TextState(L10n.tr("common.cancel"))
            }
        } message: {
            TextState(message)
        }
    }

    /// Создает алерт об успешном добавлении торрента.
    static func torrentAdded<Action>(
        name: String,
        isDuplicate: Bool,
        action: Action
    ) -> AlertState<Action> {
        AlertState {
            TextState(
                isDuplicate
                    ? L10n.tr("torrentAdd.alert.duplicate.title")
                    : L10n.tr("torrentAdd.alert.added.title")
            )
        } actions: {
            ButtonState(role: .cancel, action: action) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(
                isDuplicate
                    ? String(format: L10n.tr("torrentAdd.alert.duplicate.message"), name)
                    : String(format: L10n.tr("torrentAdd.alert.added.message"), name)
            )
        }
    }

    /// Создает алерт об ошибке добавления торрента.
    static func torrentAddFailed<Action>(
        message: String,
        action: Action
    ) -> AlertState<Action> {
        simpleAlert(
            title: L10n.tr("torrentAdd.alert.addFailed.title"),
            message: message,
            action: action
        )
    }

    /// Создает алерт об отсутствии каталога загрузки.
    static func destinationRequired<Action>(
        action: Action
    ) -> AlertState<Action> {
        simpleAlert(
            title: L10n.tr("torrentAdd.alert.destinationRequired.title"),
            message: L10n.tr("torrentAdd.alert.destinationRequired.message"),
            action: action
        )
    }

    /// Создает алерт об отсутствии соединения при добавлении торрента.
    static func noConnection<Action>(
        action: Action
    ) -> AlertState<Action> {
        simpleAlert(
            title: L10n.tr("torrentAdd.alert.noConnection.title"),
            message: L10n.tr("torrentAdd.alert.noConnection.message"),
            action: action
        )
    }

    /// Создает диалог подтверждения действия (Action Sheet).
    static func confirmationDialog<Action>(
        title: String,
        message: String,
        confirmAction: Action,
        cancelAction: Action
    ) -> ConfirmationDialogState<Action> {
        ConfirmationDialogState {
            TextState(title)
        } actions: {
            ButtonState(role: .destructive, action: confirmAction) {
                TextState(L10n.tr("common.delete"))
            }
            ButtonState(role: .cancel, action: cancelAction) {
                TextState(L10n.tr("common.cancel"))
            }
        } message: {
            TextState(message)
        }
    }
}
