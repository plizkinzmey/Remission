import SwiftUI

struct TorrentListEmptyStateView: View {
    var body: some View {
        #if os(macOS)
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.secondary)

                Text(L10n.tr("torrentList.empty.title"))
                    .font(.title2.weight(.semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .accessibilityIdentifier("torrent_list_empty_state")
        #else
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(L10n.tr("torrentList.empty.title"))
                    .font(.subheadline)
                    .bold()
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityIdentifier("torrent_list_empty_state")
        #endif
    }
}
