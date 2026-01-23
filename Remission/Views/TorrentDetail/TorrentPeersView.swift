import ComposableArchitecture
import SwiftUI

struct TorrentPeersView: View {
    let peers: IdentifiedArrayOf<PeerSource>
    var showsContainer: Bool = true

    var body: some View {
        content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(peers) { peer in
                HStack {
                    Text(peer.name)
                        .appCaption()
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(peer.count)")
                        .appCaption()
                        .appMonospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("torrent-peer-\(peer.id)")
                .accessibilityLabel(
                    String(
                        format: L10n.tr("torrentDetail.peers.accessibility"),
                        locale: Locale.current,
                        peer.name,
                        peer.count
                    )
                )
            }
        }
    }
}

#if DEBUG
    #Preview {
        TorrentPeersView(
            peers: IdentifiedArray(
                uniqueElements: [
                    PeerSource(name: "Tracker", count: 12),
                    PeerSource(name: "DHT", count: 8)
                ]
            )
        )
        .padding()
    }
#endif
