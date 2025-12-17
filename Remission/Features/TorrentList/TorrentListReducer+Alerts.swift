import ComposableArchitecture
import Foundation

extension ConfirmationDialogState
where Action == TorrentListReducer.RemoveConfirmationAction {
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
                TextState(L10n.tr("torrentDetail.actions.cancel"))
            }
        }
    }
}
