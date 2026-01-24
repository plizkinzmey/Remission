import SwiftUI

struct TorrentListHeaderView: View {
    let title: String

    var body: some View {
        HStack(alignment: .center) {
            Spacer(minLength: 0)
            Text(title)
                #if os(macOS)
                    .font(.title3.weight(.semibold))
                #else
                    .font(.headline.weight(.semibold))
                #endif
                .accessibilityIdentifier("torrent_list_header")
                #if os(iOS)
                    .allowsHitTesting(false)
                #endif
            Spacer(minLength: 0)
        }
    }
}
