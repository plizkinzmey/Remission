import ComposableArchitecture
import SwiftUI

struct TorrentPeersView: View {
    let peers: IdentifiedArrayOf<PeerSource>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(peers) { peer in
                    HStack {
                        Text(peer.name)
                            .font(.caption)
                        Spacer()
                        Text("\(peer.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
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
        } label: {
            Text(L10n.tr("torrentDetail.peers.title"))
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-peers-section")
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
