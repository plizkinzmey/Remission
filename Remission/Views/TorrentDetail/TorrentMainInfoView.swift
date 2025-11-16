import ComposableArchitecture
import SwiftUI

struct TorrentMainInfoView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TorrentDetailLabelValueRow(
                    label: "Имя:",
                    value: store.name
                )
                TorrentDetailLabelValueRow(
                    label: "Статус:",
                    value: TorrentDetailFormatters.statusText(for: store.status)
                )
                TorrentDetailLabelValueRow(
                    label: "Прогресс:",
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.progress(store.percentDone)
                        : "Недоступно"
                )
                TorrentDetailLabelValueRow(
                    label: "Размер:",
                    value: store.hasLoadedMetadata && store.totalSize > 0
                        ? TorrentDetailFormatters.bytes(store.totalSize)
                        : "Неизвестно"
                )
                TorrentDetailLabelValueRow(
                    label: "Загружено:",
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.downloadedEver)
                        : "Недоступно"
                )
                TorrentDetailLabelValueRow(
                    label: "Отдано:",
                    value: store.hasLoadedMetadata
                        ? TorrentDetailFormatters.bytes(store.uploadedEver)
                        : "Недоступно"
                )
                TorrentDetailLabelValueRow(
                    label: "Путь:",
                    value: store.hasLoadedMetadata && store.downloadDir.isEmpty == false
                        ? store.downloadDir
                        : "Неизвестно"
                )
                TorrentDetailLabelValueRow(
                    label: "Дата добавления:",
                    value: store.hasLoadedMetadata && store.dateAdded > 0
                        ? TorrentDetailFormatters.date(from: store.dateAdded)
                        : "Недоступно"
                )
                TorrentDetailLabelValueRow(
                    label: "Осталось:",
                    value: etaDescription
                )
            }
        } label: {
            Text("Основная информация")
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-main-info")
    }

    private var etaDescription: String {
        if store.eta > 0 {
            return TorrentDetailFormatters.eta(store.eta)
        }
        return store.hasLoadedMetadata ? "Неизвестно" : "Ожидание метаданных"
    }
}

#if DEBUG
    #Preview {
        TorrentMainInfoView(
            store: Store(
                initialState: TorrentDetailReducer.State(
                    torrentID: .init(rawValue: 1),
                    name: "Ubuntu ISO",
                    status: 4,
                    percentDone: 0.42,
                    totalSize: 1_024_000_000,
                    downloadedEver: 512_000_000,
                    uploadedEver: 128_000_000,
                    downloadDir: "/downloads/ubuntu",
                    dateAdded: Int(Date().timeIntervalSince1970),
                    hasLoadedMetadata: true
                )
            ) {
                TorrentDetailReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        )
        .padding()
    }
#endif
