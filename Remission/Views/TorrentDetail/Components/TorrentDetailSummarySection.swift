import ComposableArchitecture
import SwiftUI

struct TorrentDetailSummarySection: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        AppSectionCard(L10n.tr("torrentDetail.section.summary")) {
            ViewThatFits(in: .horizontal) {
                summaryHeaderWide
                summaryHeaderNarrow
            }
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier("torrent-summary")
    }

    private var summaryHeaderWide: some View {
        Group {
            if shouldShowTransferMetrics {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 12)
                    summaryMetricsCompact
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var summaryHeaderNarrow: some View {
        Group {
            if shouldShowTransferMetrics {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 8)
                    summaryMetricsCompact
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Spacer(minLength: 0)
                    summaryStatusCluster
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var summaryStatusCluster: some View {
        HStack(alignment: .top, spacing: 16) {
            summaryProgressView
            summaryStatusStack
        }
    }

    private var summaryProgressView: some View {
        let progress = store.hasLoadedMetadata ? clampedProgress : 0
        return ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 52, height: 52)
        .accessibilityLabel(L10n.tr("torrentDetail.progress.accessibility"))
        .accessibilityValue(progressDescription)
        .accessibilityIdentifier("torrent-progress")
    }

    private var summaryStatusStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(progressDescription)
                .font(.title3.weight(.semibold))
            Text(TorrentDetailFormatters.statusText(for: store.status))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    private var summaryMetricsCompact: some View {
        VStack(alignment: .leading, spacing: 10) {
            SummaryMetricCompactRow(
                icon: "arrow.down.circle.fill",
                title: L10n.tr("torrentDetail.metric.downloadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateDownload)
            )
            SummaryMetricCompactRow(
                icon: "arrow.up.circle.fill",
                title: L10n.tr("torrentDetail.metric.uploadSpeed"),
                value: TorrentDetailFormatters.speed(store.rateUpload)
            )
            SummaryMetricCompactRow(
                icon: "person.fill",
                title: L10n.tr("torrentDetail.metric.peers"),
                value: "\(store.peersConnected)"
            )
            #if os(macOS)
                SummaryMetricCompactRow(
                    icon: "gauge.with.dots.needle.100percent",
                    title: L10n.tr("torrentDetail.metric.ratio"),
                    value: String(format: "%.2f", store.uploadRatio)
                )
            #endif
        }
        .frame(minWidth: 180, alignment: .leading)
    }

    private var progressDescription: String {
        guard store.hasLoadedMetadata else {
            return L10n.tr("torrentDetail.progress.none")
        }
        let percent = max(0, min(100, Int((effectiveProgress * 100).rounded())))
        return "\(percent)%"
    }

    private var clampedProgress: Double {
        max(0, min(effectiveProgress, 1))
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

    private var shouldShowTransferMetrics: Bool {
        store.status == Torrent.Status.downloading.rawValue
            || store.status == Torrent.Status.seeding.rawValue
    }
}
