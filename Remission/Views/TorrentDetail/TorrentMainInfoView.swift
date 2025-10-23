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
                    value: TorrentDetailFormatters.progress(store.percentDone)
                )
                TorrentDetailLabelValueRow(
                    label: "Размер:",
                    value: TorrentDetailFormatters.bytes(store.totalSize)
                )
                TorrentDetailLabelValueRow(
                    label: "Загружено:",
                    value: TorrentDetailFormatters.bytes(store.downloadedEver)
                )
                TorrentDetailLabelValueRow(
                    label: "Отдано:",
                    value: TorrentDetailFormatters.bytes(store.uploadedEver)
                )
                TorrentDetailLabelValueRow(
                    label: "Путь:",
                    value: store.downloadDir
                )
                TorrentDetailLabelValueRow(
                    label: "Дата добавления:",
                    value: TorrentDetailFormatters.date(from: store.dateAdded)
                )
                if store.eta > 0 {
                    TorrentDetailLabelValueRow(
                        label: "Осталось:",
                        value: TorrentDetailFormatters.eta(store.eta)
                    )
                }
            }
        } label: {
            Text("Основная информация")
                .font(.headline)
        }
    }
}

#if DEBUG
    #Preview {
        TorrentMainInfoView(
            store: Store(
                initialState: TorrentDetailState(torrentId: 1),
                reducer: { TorrentDetailReducer() }
            )
        )
        .padding()
    }
#endif
