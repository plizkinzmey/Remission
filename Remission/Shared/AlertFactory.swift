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
