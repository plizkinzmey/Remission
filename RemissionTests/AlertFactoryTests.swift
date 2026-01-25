import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("Alert Factory Tests")
struct AlertFactoryTests {
    private enum Action: Equatable {
        case confirm
        case cancel
        case ok
    }

    // Проверяет, что алерт удаления содержит две кнопки: destructive confirm и cancel.
    @Test
    func deleteConfirmationBuildsDestructiveAndCancelButtons() {
        let alert = AlertFactory.deleteConfirmation(
            title: "Удалить",
            message: "Точно удалить?",
            confirmAction: Action.confirm,
            cancelAction: Action.cancel
        )

        #expect(alert.buttons.count == 2)
    }

    // Проверяет, что простой алерт содержит ровно одну кнопку.
    @Test
    func simpleAlertBuildsSingleButton() {
        let alert = AlertFactory.simpleAlert(
            title: "Готово",
            message: "Операция завершена",
            action: Action.ok
        )

        #expect(alert.buttons.count == 1)
    }

    // Проверяет, что алерт подтверждения действия содержит две кнопки.
    @Test
    func confirmationBuildsTwoButtons() {
        let alert = AlertFactory.confirmation(
            title: "Продолжить",
            message: "Выполнить действие?",
            confirmText: "Да",
            confirmAction: Action.confirm,
            cancelAction: Action.cancel
        )

        #expect(alert.buttons.count == 2)
    }

    // Проверяет, что алерт успешного добавления торрента содержит одну кнопку.
    @Test(
        "Torrent added alert has single button",
        arguments: [false, true]
    )
    func torrentAddedBuildsSingleButton(isDuplicate: Bool) {
        let alert = AlertFactory.torrentAdded(
            name: "Ubuntu.iso",
            isDuplicate: isDuplicate,
            action: Action.ok
        )

        #expect(alert.buttons.count == 1)
    }

    // Проверяет, что ConfirmationDialog содержит две кнопки.
    @Test
    func confirmationDialogBuildsTwoButtons() {
        let dialog = AlertFactory.confirmationDialog(
            title: "Удалить",
            message: "Это действие необратимо",
            confirmAction: Action.confirm,
            cancelAction: Action.cancel
        )

        #expect(dialog.buttons.count == 2)
    }
}
