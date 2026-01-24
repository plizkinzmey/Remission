import SwiftUI

struct TorrentListHeaderView: View {
    let title: String

    var body: some View {
        #if os(macOS)
            HStack(alignment: .center) {
                Spacer(minLength: 0)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("torrent_list_header")
                Spacer(minLength: 0)
            }
        #else
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityIdentifier("torrent_list_header")
                .allowsHitTesting(false)
        #endif
    }
}
