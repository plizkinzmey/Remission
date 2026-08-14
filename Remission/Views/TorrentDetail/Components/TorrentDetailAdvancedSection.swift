import ComposableArchitecture
import SwiftUI

struct TorrentDetailAdvancedSection: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    @Binding var isFilesExpanded: Bool
    @Binding var isTrackersExpanded: Bool
    @Binding var isPeersExpanded: Bool

    var body: some View {
        AppSectionCard("") {
            TorrentDetailSection(
                title: String(
                    format: L10n.tr("torrentDetail.files.title"), Int64(store.files.files.count)),
                isExpanded: $isFilesExpanded,
                hasMetadata: store.hasLoadedMetadata,
                isEmpty: store.files.files.isEmpty,
                emptyIcon: "doc.text.magnifyingglass",
                emptyTitleLoaded: L10n.tr("torrentDetail.files.empty.title.loaded"),
                emptyTitleLoading: L10n.tr("torrentDetail.files.empty.title.loading"),
                emptyMessageLoaded: L10n.tr("torrentDetail.files.empty.message.loaded"),
                emptyMessageLoading: L10n.tr("torrentDetail.files.empty.message.loading"),
                accessibilityIdentifier: "torrent-files-section"
            ) {
                TorrentFilesView(store: store, showsContainer: false)
            }

            TorrentDetailSection(
                title: String(
                    format: L10n.tr("torrentDetail.trackers.title"),
                    Int64(store.trackers.trackers.count)
                ),
                isExpanded: $isTrackersExpanded,
                hasMetadata: store.hasLoadedMetadata,
                isEmpty: store.trackers.trackers.isEmpty,
                emptyIcon: "dot.radiowaves.left.and.right",
                emptyTitleLoaded: L10n.tr("torrentDetail.trackers.empty.title.loaded"),
                emptyTitleLoading: L10n.tr("torrentDetail.trackers.empty.title.loading"),
                emptyMessageLoaded: L10n.tr("torrentDetail.trackers.empty.message.loaded"),
                emptyMessageLoading: L10n.tr("torrentDetail.trackers.empty.message.loading"),
                accessibilityIdentifier: "torrent-trackers-section"
            ) {
                TorrentTrackersView(store: store, showsContainer: false)
            }

            TorrentDetailSection(
                title: L10n.tr("torrentDetail.peers.title"),
                isExpanded: $isPeersExpanded,
                hasMetadata: store.hasLoadedMetadata,
                isEmpty: store.peers.peers.isEmpty,
                emptyIcon: "person.2.wave.2.fill",
                emptyTitleLoaded: L10n.tr("torrentDetail.peers.empty.title.loaded"),
                emptyTitleLoading: L10n.tr("torrentDetail.peers.empty.title.loading"),
                emptyMessageLoaded: L10n.tr("torrentDetail.peers.empty.message.loaded"),
                emptyMessageLoading: L10n.tr("torrentDetail.peers.empty.message.loading"),
                accessibilityIdentifier: "torrent-peers-section"
            ) {
                TorrentPeersView(peers: store.peers.peers, showsContainer: false)
            }
        }
    }
}
