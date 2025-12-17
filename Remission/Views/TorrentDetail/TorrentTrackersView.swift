import ComposableArchitecture
import SwiftUI

struct TorrentTrackersView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    var showsContainer: Bool = true

    var body: some View {
        if showsContainer {
            GroupBox {
                content
            } label: {
                Text(
                    String(
                        format: L10n.tr("torrentDetail.trackers.title"),
                        Int64(store.trackers.count)
                    )
                )
                .font(.headline)
            }
            .accessibilityIdentifier("torrent-trackers-section")
        } else {
            content
        }
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
                initialState: TorrentDetailReducer.State(
                    torrentID: .init(rawValue: 1),
                    trackers: [
                        TorrentTracker(
                            id: 0,
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
