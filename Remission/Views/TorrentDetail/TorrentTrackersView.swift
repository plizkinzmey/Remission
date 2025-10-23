import ComposableArchitecture
import SwiftUI

struct TorrentTrackersView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(store.trackers) { tracker in
                    let stats: TrackerStat? = store
                        .trackerStats
                        .first { $0.trackerId == tracker.index }
                    TorrentTrackerRow(tracker: tracker, stats: stats)
                }
            }
        } label: {
            Text("Трекеры (\(store.trackers.count))")
                .font(.headline)
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
    }
}

#if DEBUG
    #Preview {
        TorrentTrackersView(
            store: Store(
                initialState: TorrentDetailState(
                    torrentId: 1,
                    trackers: [
                        TorrentTracker(
                            index: 0,
                            announce: "https://tracker.example.com/announce",
                            tier: 0
                        )
                    ],
                    trackerStats: [
                        TrackerStat(
                            trackerId: 0,
                            lastAnnounceResult: "Success",
                            downloadCount: 10,
                            leecherCount: 5,
                            seederCount: 25
                        )
                    ]
                ),
                reducer: { TorrentDetailReducer() }
            )
        )
        .padding()
    }
#endif
