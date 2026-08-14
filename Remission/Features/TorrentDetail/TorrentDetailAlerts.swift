import ComposableArchitecture
import Foundation

extension AlertState where Action == TorrentDetailReducer.AlertAction {
    static func connectionMissing() -> Self {
        Self {
            TextState(L10n.tr("torrentDetail.error.title"))
        } actions: {
            ButtonState(action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(L10n.tr("torrentAdd.alert.noConnection.title"))
        }
    }

    static func info(message: String) -> Self {
        Self {
            TextState(L10n.tr("common.ok"))
        } actions: {
            ButtonState(action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
    }

    static func error(message: String) -> Self {
        Self {
            TextState(L10n.tr("torrentDetail.error.title"))
        } actions: {
            ButtonState(action: .dismiss) {
                TextState(L10n.tr("common.ok"))
            }
        } message: {
            TextState(message)
        }
    }
}

extension ConfirmationDialogState where Action == TorrentDetailReducer.RemoveConfirmationAction {
    static func removeTorrent(name: String) -> Self {
        Self {
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
