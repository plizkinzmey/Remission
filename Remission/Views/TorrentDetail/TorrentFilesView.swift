import ComposableArchitecture
import SwiftUI

struct TorrentFilesView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.files) { file in
                    TorrentFileRow(file: file) { priority in
                        store.send(.setPriority(fileIndices: [file.index], priority: priority))
                    }
                }
            }
        } label: {
            Text("Файлы (\(store.files.count))")
                .font(.headline)
        }
    }
}

private struct TorrentFileRow: View {
    let file: TorrentFile
    let onPriorityChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                Text(TorrentDetailFormatters.bytes(file.length))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                ProgressView(value: file.progress)
                    .progressViewStyle(.linear)
                Text("\(Int(file.progress * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                Menu {
                    Button("Низкий") { onPriorityChange(0) }
                    Button("Нормальный") { onPriorityChange(1) }
                    Button("Высокий") { onPriorityChange(2) }
                } label: {
                    Text(TorrentDetailFormatters.priorityText(file.priority))
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            TorrentDetailFormatters.priorityColor(file.priority).opacity(0.2)
                        )
                        .foregroundStyle(
                            TorrentDetailFormatters.priorityColor(file.priority)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
    #Preview {
        TorrentFilesView(
            store: Store(
                initialState: TorrentDetailReducer.State(
                    torrentId: 1,
                    files: [
                        TorrentFile(
                            index: 0,
                            name: "ubuntu.iso",
                            length: 1_024_000,
                            bytesCompleted: 512_000,
                            priority: 1,
                            wanted: true
                        )
                    ]
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
