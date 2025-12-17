import ComposableArchitecture
import SwiftUI

struct TorrentFilesView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    var showsContainer: Bool = true

    var body: some View {
        if showsContainer {
            GroupBox {
                content
            } label: {
                Text(
                    String(
                        format: L10n.tr("torrentDetail.files.title"),
                        Int64(store.files.count)
                    )
                )
                .font(.headline)
            }
            .accessibilityIdentifier("torrent-files-section")
            .disabled(isPriorityLocked)
        } else {
            content
                .disabled(isPriorityLocked)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.files) { file in
                TorrentFileRow(file: file) { priority in
                    store.send(
                        .priorityChanged(fileIndices: [file.index], priority: priority))
                }
            }
        }
    }

    private var isPriorityLocked: Bool {
        store.withState { $0.isCommandCategoryLocked(.priority) }
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
                    .accessibilityLabel(L10n.tr("torrentDetail.files.progress.accessibility"))
                    .accessibilityValue(progressText)
                Text("\(Int(file.progress * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)

                Menu {
                    Button(L10n.tr("torrentDetail.priority.low")) { onPriorityChange(0) }
                    Button(L10n.tr("torrentDetail.priority.normal")) { onPriorityChange(1) }
                    Button(L10n.tr("torrentDetail.priority.high")) { onPriorityChange(2) }
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
                .accessibilityIdentifier("torrent-file-priority-\(file.index)")
                .accessibilityLabel(
                    String(
                        format: L10n.tr("torrentDetail.files.priority.accessibilityLabel"),
                        TorrentDetailFormatters.priorityText(file.priority)
                    )
                )
                .accessibilityHint(L10n.tr("torrentDetail.files.priority.hint"))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("torrent-file-\(file.index)")
        .accessibilityLabel(
            String(
                format: L10n.tr("torrentDetail.files.accessibility.label"),
                file.name,
                progressText,
                TorrentDetailFormatters.bytes(file.length)
            )
        )
    }

    private var progressText: String {
        String(
            format: L10n.tr("torrentDetail.files.progress.percent"),
            Int(file.progress * 100)
        )
    }
}

#if DEBUG
    #Preview {
        TorrentFilesView(
            store: Store(
                initialState: TorrentDetailReducer.State(
                    torrentID: .init(rawValue: 1),
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
