import SwiftUI

struct TorrentListEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label(L10n.tr("torrentList.empty.title"), systemImage: "tray")
        }
        .accessibilityIdentifier("torrent_list_empty_state")
    }
}
