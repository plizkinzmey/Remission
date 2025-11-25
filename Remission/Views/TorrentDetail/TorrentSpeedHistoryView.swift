import SwiftUI

#if canImport(Charts)
    import Charts
#endif

struct TorrentSpeedHistoryView: View {
    let samples: [SpeedSample]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                if samples.isEmpty {
                    EmptyPlaceholderView(
                        systemImage: "waveform.path",
                        title: L10n.tr("torrentDetail.speedHistory.empty.title"),
                        message: L10n.tr("torrentDetail.speedHistory.empty.message")
                    )
                    .accessibilityIdentifier("torrent-speed-history-empty")
                } else {
                    #if canImport(Charts)
                        SpeedHistoryChart(samples: samples)
                            .frame(height: 180)
                            .accessibilityIdentifier("torrent-speed-history-chart")
                    #else
                        Text(L10n.tr("torrentDetail.speedHistory.unavailable"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    #endif
                    HStack(spacing: 12) {
                        Label(
                            L10n.tr("torrentDetail.speedHistory.download"),
                            systemImage: "arrow.down.circle.fill"
                        )
                        .foregroundStyle(.green)
                        Label(
                            L10n.tr("torrentDetail.speedHistory.upload"),
                            systemImage: "arrow.up.circle.fill"
                        )
                        .foregroundStyle(.blue)
                    }
                    .font(.caption)
                    Divider()
                    historyRows
                }
            }
        } label: {
            Text(L10n.tr("torrentDetail.speedHistory.title"))
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-speed-history-section")
    }

    private var historyRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(recentSamples, id: \.timestamp) { sample in
                HStack {
                    Text(sample.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("↓ \(TorrentDetailFormatters.speed(sample.downloadRate))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.green)
                    Text("↑ \(TorrentDetailFormatters.speed(sample.uploadRate))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.blue)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(
                        format: L10n.tr("torrentDetail.speedHistory.accessibility"),
                        sample.timestamp.formatted(date: .omitted, time: .shortened),
                        TorrentDetailFormatters.speed(sample.downloadRate),
                        TorrentDetailFormatters.speed(sample.uploadRate)
                    )
                )
            }
        }
    }

    private var recentSamples: [SpeedSample] {
        Array(samples.suffix(5))
    }
}

#if canImport(Charts)
    private struct SpeedHistoryChart: View {
        let samples: [SpeedSample]

        var body: some View {
            Chart {
                ForEach(samples, id: \.timestamp) { sample in
                    LineMark(
                        x: .value(L10n.tr("torrentDetail.speedHistory.axis.x"), sample.timestamp),
                        y: .value(
                            L10n.tr("torrentDetail.speedHistory.download"),
                            kilobytes(sample.downloadRate))
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value(L10n.tr("torrentDetail.speedHistory.axis.x"), sample.timestamp),
                        y: .value(
                            L10n.tr("torrentDetail.speedHistory.upload"),
                            kilobytes(sample.uploadRate))
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartYAxisLabel(L10n.tr("torrentDetail.speedHistory.axis.y"))
            .chartXAxisLabel(L10n.tr("torrentDetail.speedHistory.axis.x"))
            .accessibilityLabel(L10n.tr("torrentDetail.speedHistory.title"))
        }

        private func kilobytes(_ value: Int) -> Double {
            Double(value) / 1024.0
        }
    }
#endif

#if DEBUG
    #Preview {
        TorrentSpeedHistoryView(
            samples: [
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-300),
                    downloadRate: 2_200_000,
                    uploadRate: 400_000
                ),
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-240),
                    downloadRate: 2_450_000,
                    uploadRate: 420_000
                ),
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-180),
                    downloadRate: 2_700_000,
                    uploadRate: 430_000
                ),
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-120),
                    downloadRate: 2_850_000,
                    uploadRate: 440_000
                ),
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-60),
                    downloadRate: 3_000_000,
                    uploadRate: 450_000
                ),
                SpeedSample(
                    timestamp: Date(),
                    downloadRate: 3_200_000,
                    uploadRate: 470_000
                )
            ]
        )
        .padding()
    }
#endif
