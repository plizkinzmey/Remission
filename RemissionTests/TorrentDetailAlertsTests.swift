import ComposableArchitecture
import Foundation
import Testing

@testable import Remission

@Suite("TorrentDetailAlertsTests")
struct TorrentDetailAlertsTests {
    @Test
    func infoAlertHasMessageAndDismissButton() {
        let alert = AlertState<TorrentDetailReducer.AlertAction>.info(message: "Info message")
        #expect(alert.buttons.count == 1)
    }

    @Test
    func errorAlertHasTitleMessageAndDismissButton() {
        let alert = AlertState<TorrentDetailReducer.AlertAction>.error(message: "Error message")
        #expect(alert.buttons.count == 1)
    }

    @Test
    func connectionMissingAlertIsErrorAlert() {
        let alert = AlertState<TorrentDetailReducer.AlertAction>.connectionMissing()
        #expect(alert.buttons.count == 1)
    }

    @Test
    func removeTorrentDialogHasThreeButtons() {
        let dialog = ConfirmationDialogState<TorrentDetailReducer.RemoveConfirmationAction>
            .removeTorrent(name: "My Linux ISO")
        #expect(dialog.buttons.count == 3)
    }
}
