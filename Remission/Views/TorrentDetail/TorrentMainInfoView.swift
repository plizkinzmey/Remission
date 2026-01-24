import ComposableArchitecture
import SwiftUI

struct TorrentMainInfoView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.name"),
                    value: store.name
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.status"),
                    value: TorrentDetailFormatters.statusText(for: store.status)
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.progress"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.progress(store.percentDone)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.size"),
                    value: store.hasLoadedMetadata && store.totalSize > 0
                        ? TorrentDetailFormatters.bytes(store.totalSize)
                        : L10n.tr("torrentDetail.mainInfo.unknown")
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.downloaded"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.downloadedEver)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.uploaded"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.uploadedEver)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.path"),
                    value: store.hasLoadedMetadata && store.downloadDir.isEmpty == false
                        ? store.downloadDir
                        : L10n.tr("torrentDetail.mainInfo.unknown")
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.added"),
                    value: store.hasLoadedMetadata && store.dateAdded > 0
                        ? TorrentDetailFormatters.date(from: store.dateAdded)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.eta"),
                    value: etaDescription
                )
            }
        } label: {
            Text(L10n.tr("torrentDetail.mainInfo.title"))
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-main-info")
    }

    private var etaDescription: String {
        if store.eta > 0 {
            return TorrentDetailFormatters.eta(store.eta)
        }
        return store.hasLoadedMetadata
            ? L10n.tr("torrentDetail.mainInfo.unknown")
            : L10n.tr("torrentDetail.mainInfo.waitingMetadata")
    }
}

#Preview {
    TorrentMainInfoView(
        store: Store(
            initialState: {
                var state = TorrentDetailReducer.State(torrentID: .init(rawValue: 1))
                state.apply(.previewDownloading)
                return state
            }()
        ) {
            TorrentDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }
    )
    .padding()
}
