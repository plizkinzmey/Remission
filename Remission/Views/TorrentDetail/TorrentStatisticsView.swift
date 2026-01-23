import ComposableArchitecture
import SwiftUI

struct TorrentStatisticsView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    var showsContainer: Bool = true

    var body: some View {
        content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.stats.downloadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateDownload)
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.stats.uploadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateUpload)
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.stats.ratio"),
                value: String(format: "%.2f", store.uploadRatio)
            )
            TorrentDetailLabelValueRow(
                label: L10n.tr("torrentDetail.stats.peers"),
                value: "\(store.peersConnected)"
            )

            Divider().padding(.vertical, 4)

            downloadLimitControls
            uploadLimitControls
        }
    }

    private var downloadLimitControls: some View {
        TorrentLimitControl(
            title: L10n.tr("torrentDetail.stats.downloadLimit"),
            isEnabled: Binding(
                get: { store.downloadLimited },
                set: { store.send(.toggleDownloadLimit($0)) }
            ),
            value: Binding(
                get: { store.downloadLimit },
                set: { store.send(.downloadLimitChanged($0)) }
            )
        )
    }

    private var uploadLimitControls: some View {
        TorrentLimitControl(
            title: L10n.tr("torrentDetail.stats.uploadLimit"),
            isEnabled: Binding(
                get: { store.uploadLimited },
                set: { store.send(.toggleUploadLimit($0)) }
            ),
            value: Binding(
                get: { store.uploadLimit },
                set: { store.send(.uploadLimitChanged($0)) }
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
                    .appCaption()
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                    .accessibilityIdentifier("torrent_limit_toggle_\(identifierSuffix)")
            }

            if isEnabled.wrappedValue {
                HStack {
                    Text(L10n.tr("torrentDetail.stats.valueLabel"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField(
                        L10n.tr("torrentDetail.stats.placeholder"), value: value, format: .number
                    )
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .frame(maxWidth: 180)
                    .appPillSurface()
                    .appMonospacedDigit()
                    .accessibilityIdentifier("torrent_limit_value_\(identifierSuffix)")
                    #if os(macOS)
                        .controlSize(.small)
                    #endif
                }
            }
        }
    }

    private var identifierSuffix: String {
        title.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
    }
}

#if DEBUG
    #Preview {
        TorrentStatisticsView(
            store: Store(
                initialState: TorrentDetailReducer.State(torrentID: .init(rawValue: 1))
            ) {
                TorrentDetailReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        )
        .padding()
    }
#endif
