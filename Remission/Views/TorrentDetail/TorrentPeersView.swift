import ComposableArchitecture
import SwiftUI

struct TorrentPeersView: View {
    let peers: IdentifiedArrayOf<PeerSource>

    var body: some View {
        GroupBox {
            if peers.isEmpty {
                EmptyPlaceholderView(
                    systemImage: "person.2.wave.2.fill",
                    title: "Нет источников",
                    message: "Список источников пиров пока пуст. Проверьте подключение к трекерам."
                )
                .accessibilityIdentifier("torrent-peers-empty")
            } else {
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
                        .accessibilityLabel("\(peer.name): \(peer.count) источников")
                    }
                }
            }
        } label: {
            Text("Источники пиров")
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
