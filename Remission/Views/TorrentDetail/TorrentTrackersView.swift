import ComposableArchitecture
import SwiftUI

struct TorrentTrackersView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    var showsContainer: Bool = true

    var body: some View {
        content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.trackers) { tracker in
                let stats: TrackerStat? = store
                    .trackerStats
                    .first { $0.trackerId == tracker.id }
                TorrentTrackerRow(tracker: tracker, stats: stats)
            }
        }
    }
}

private struct TorrentTrackerRow: View {
    let tracker: TorrentTracker
    let stats: TrackerStat?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tracker.displayName)
                .font(.caption.weight(.medium))

            Text(tracker.announce)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let stats {
                HStack(spacing: 12) {
                    Label("\(stats.seederCount)", systemImage: "arrow.up.circle.fill")
                    Label("\(stats.leecherCount)", systemImage: "arrow.down.circle.fill")
                    if !stats.lastAnnounceResult.isEmpty && stats.lastAnnounceResult != "Success" {
                        Text(stats.lastAnnounceResult)
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("torrent-tracker-\(tracker.id)")
        .accessibilityLabel(
            String(
                format: L10n.tr("torrentDetail.trackers.accessibility"),
                tracker.displayName,
                tracker.announce,
                stats?.seederCount ?? 0,
                stats?.leecherCount ?? 0
            )
        )
    }
}

#if DEBUG
    #Preview {
        TorrentTrackersView(
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
#endif
