import ComposableArchitecture
import Foundation

extension AlertState where Action == TorrentDetailReducer.AlertAction {
    static func info(message: String) -> AlertState {
        AlertState {
            TextState(L10n.tr("common.ok"))
        } actions: {
            ButtonState(action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
    }

    static func error(message: String) -> AlertState {
        AlertState {
            TextState(L10n.tr("torrentDetail.error.title"))
        } actions: {
            ButtonState(action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
    }

    static func connectionMissing() -> AlertState {
        .error(message: L10n.tr("torrentAdd.alert.noConnection.title"))
    }
}

extension ConfirmationDialogState
where Action == TorrentDetailReducer.RemoveConfirmationAction {
    static func removeTorrent(name: String) -> ConfirmationDialogState {
        ConfirmationDialogState {
            TextState(
                String(
                    format: L10n.tr("torrentDetail.actions.removePrompt"),
                    name.isEmpty ? L10n.tr("torrentDetail.title.fallback") : name
                )
            )
        } actions: {
            ButtonState(role: .destructive, action: .deleteTorrentOnly) {
                TextState(L10n.tr("torrentDetail.actions.remove.confirm"))
            }
            ButtonState(role: .destructive, action: .deleteWithData) {
                TextState(L10n.tr("torrentDetail.actions.removeWithData"))
            }
            ButtonState(role: .cancel, action: .cancel) {
                TextState(L10n.tr("common.cancel"))
            }
        }
    }
}
