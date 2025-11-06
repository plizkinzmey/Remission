import ComposableArchitecture
import SwiftUI

struct TorrentStatisticsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                TorrentDetailLabelValueRow(
                    label: "Скорость загрузки:",
                    value: TorrentDetailFormatters.speed(store.rateDownload)
                )
                TorrentDetailLabelValueRow(
                    label: "Скорость отдачи:",
                    value: TorrentDetailFormatters.speed(store.rateUpload)
                )
                TorrentDetailLabelValueRow(
                    label: "Коэффициент:",
                    value: String(format: "%.2f", store.uploadRatio)
                )
                TorrentDetailLabelValueRow(
                    label: "Пиров подключено:",
                    value: "\(store.peersConnected)"
                )

                Divider().padding(.vertical, 4)

                downloadLimitControls
                uploadLimitControls
            }
        } label: {
            Text("Статистика")
                .font(.headline)
        }
    }

    private var downloadLimitControls: some View {
        TorrentLimitControl(
            title: "Лимит загрузки:",
            isEnabled: Binding(
                get: { store.downloadLimited },
                set: { store.send(.toggleDownloadLimit($0)) }
            ),
            value: Binding(
                get: { store.downloadLimit },
                set: { store.send(.updateDownloadLimit($0)) }
            )
        )
    }

    private var uploadLimitControls: some View {
        TorrentLimitControl(
            title: "Лимит отдачи:",
            isEnabled: Binding(
                get: { store.uploadLimited },
                set: { store.send(.toggleUploadLimit($0)) }
            ),
            value: Binding(
                get: { store.uploadLimit },
                set: { store.send(.updateUploadLimit($0)) }
            )
        )
    }
}

private struct TorrentLimitControl: View {
    let title: String
    let isEnabled: Binding<Bool>
    let value: Binding<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
            }

            if isEnabled.wrappedValue {
                HStack {
                    Text("Значение (КБ/с):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("КБ/с", value: value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        #if os(macOS)
                            .controlSize(.small)
                        #endif
                }
            }
        }
    }
}

#if DEBUG
    #Preview {
        TorrentStatisticsView(
            store: Store(
                initialState: TorrentDetailReducer.State(torrentId: 1)
            ) {
                TorrentDetailReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        )
        .padding()
    }
#endif
