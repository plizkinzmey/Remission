import ComposableArchitecture
import SwiftUI

struct TorrentDetailInfoSection: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        AppSectionCard(L10n.tr("torrentDetail.mainInfo.title")) {
            VStack(alignment: .leading, spacing: 10) {
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.status"),
                    value: TorrentDetailFormatters.statusText(for: store.status)
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.progress"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.progress(effectiveProgress)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.size"),
                    value: store.hasLoadedMetadata && store.totalSize > 0
                        ? TorrentDetailFormatters.bytes(store.totalSize)
                        : L10n.tr("torrentDetail.mainInfo.unknown"),
                    monospacedValue: true
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.downloaded"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.downloadedEver)
                        : L10n.tr("torrentDetail.mainInfo.unavailable"),
                    monospacedValue: true
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.uploaded"),
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.uploadedEver)
                        : L10n.tr("torrentDetail.mainInfo.unavailable"),
                    monospacedValue: true
                )
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.path"),
                    value: store.hasLoadedMetadata && store.downloadDir.isEmpty == false
                        ? store.downloadDir
                        : L10n.tr("torrentDetail.mainInfo.unknown")
                )
                Divider()
                categoryRow
                Divider()
                TorrentDetailLabelValueRow(
                    label: L10n.tr("torrentDetail.mainInfo.added"),
                    value: store.hasLoadedMetadata && store.dateAdded > 0
                        ? TorrentDetailFormatters.date(from: store.dateAdded)
                        : L10n.tr("torrentDetail.mainInfo.unavailable")
                )
                if shouldShowEtaRow {
                    Divider()
                    TorrentDetailLabelValueRow(
                        label: L10n.tr("torrentDetail.mainInfo.eta"),
                        value: etaDescription,
                        monospacedValue: true
                    )
                }
            }
        }
        .accessibilityIdentifier("torrent-main-info")
    }

    private var categoryRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(L10n.tr("torrentDetail.mainInfo.category"))
                .appCaption()
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            #if os(macOS)
                Menu {
                    ForEach(TorrentCategory.ordered, id: \.self) { category in
                        Button(category.title) {
                            store.send(.categoryChanged(category))
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(store.category.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(width: 170, height: 34)
                    .contentShape(Rectangle())
                    .appToolbarPillSurface()
                }
                .accessibilityIdentifier("torrent_detail_category_picker")
                .buttonStyle(.plain)
            #else
                Picker(
                    "",
                    selection: Binding(
                        get: { store.category },
                        set: { store.send(.categoryChanged($0)) }
                    )
                ) {
                    ForEach(TorrentCategory.ordered, id: \.self) { category in
                        Text(category.title)
                            .tag(category)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .accessibilityIdentifier("torrent_detail_category_picker")
            #endif
        }
    }

    private var effectiveProgress: Double {
        switch store.status {
        case Torrent.Status.checkWaiting.rawValue,
            Torrent.Status.checking.rawValue:
            return store.recheckProgress
        default:
            return store.percentDone
        }
    }

    private var shouldShowEtaRow: Bool {
        store.status == Torrent.Status.downloading.rawValue
            || store.status == Torrent.Status.seeding.rawValue
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
