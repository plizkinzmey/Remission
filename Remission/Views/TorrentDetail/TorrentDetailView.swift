import ComposableArchitecture
import SwiftUI

struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                summarySection

                if let errorMessage = store.errorMessage {
                    TorrentErrorView(
                        message: errorMessage,
                        onDismiss: { store.send(.dismissError) }
                    )
                }

                if shouldShowInitialPlaceholder {
                    EmptyPlaceholderView(
                        systemImage: "arrow.clockwise.circle",
                        title: "Получаем данные",
                        message: "Как только сервер Transmission вернёт детали, они появятся здесь."
                    )
                    .accessibilityIdentifier("torrent-detail-initial-placeholder")
                }

                TorrentMainInfoView(store: store)
                TorrentStatisticsView(store: store)
                TorrentSpeedHistoryView(samples: store.speedHistory.samples)
                TorrentActionsView(store: store)
                TorrentFilesView(store: store)
                TorrentTrackersView(store: store)
                TorrentPeersView(peers: store.peers)
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .navigationTitle(store.name.isEmpty ? "Торрент" : store.name)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await store.send(.task).finish()
        }
        .refreshable {
            await store.send(.refreshRequested).finish()
        }
        .alert(
            $store.scope(state: \.alert, action: \.alert)
        )
        .confirmationDialog(
            $store.scope(state: \.removeConfirmation, action: \.removeConfirmation)
        )
        .overlay(alignment: .center) {
            if store.isLoading {
                loadingOverlay
            }
        }
        .onDisappear {
            store.send(.teardown)
        }
    }

    private var shouldShowInitialPlaceholder: Bool {
        store.isLoading
            && store.files.isEmpty
            && store.trackers.isEmpty
            && store.peers.isEmpty
            && store.speedHistory.samples.isEmpty
    }

    @ViewBuilder
    private var summarySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ProgressView(value: store.percentDone, total: 1.0)
                        .progressViewStyle(.circular)
                        .frame(width: 52, height: 52)
                        .accessibilityLabel("Прогресс загрузки")
                        .accessibilityValue(progressDescription)
                        .accessibilityIdentifier("torrent-progress")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(progressDescription)
                            .font(.title3.weight(.semibold))
                        Text(TorrentDetailFormatters.statusText(for: store.status))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if store.eta > 0 {
                            Text("Осталось \(TorrentDetailFormatters.eta(store.eta))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("ETA недоступно")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                summaryMetrics
            }
        } label: {
            Text("Сводка")
                .font(.headline)
        }
        .accessibilityIdentifier("torrent-summary")
    }

    private var summaryMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            SummaryMetricRow(
                icon: "arrow.down.circle.fill",
                title: "Скорость загрузки",
                value: TorrentDetailFormatters.speed(store.rateDownload)
            )
            SummaryMetricRow(
                icon: "arrow.up.circle.fill",
                title: "Скорость отдачи",
                value: TorrentDetailFormatters.speed(store.rateUpload)
            )
            SummaryMetricRow(
                icon: "person.3.sequence.fill",
                title: "Пиров подключено",
                value: "\(store.peersConnected)"
            )
        }
    }

    private var progressDescription: String {
        let percent = max(0, min(100, Int((store.percentDone * 100).rounded())))
        return "\(percent)%"
    }

    private var loadingOverlay: some View {
        ProgressView("Обновляем детали…")
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .accessibilityIdentifier("torrent-detail-loading")
    }
}

private struct SummaryMetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#if DEBUG
    #Preview {
        let previewState: TorrentDetailReducer.State = {
            var state = TorrentDetailReducer.State(
                torrentID: .init(rawValue: 1),
                name: "Ubuntu 22.04 LTS Desktop",
                status: 4,
                percentDone: 0.45,
                totalSize: 3_500_000_000,
                downloadedEver: 1_575_000_000,
                uploadedEver: 500_000_000,
                eta: 3600,
                rateDownload: 2_500_000,
                rateUpload: 500_000,
                uploadRatio: 0.32,
                downloadLimit: 1_024,
                downloadLimited: false,
                uploadLimit: 512,
                uploadLimited: true,
                peersConnected: 45,
                peers: [
                    PeerSource(name: "Tracker", count: 30),
                    PeerSource(name: "DHT", count: 10),
                    PeerSource(name: "PEX", count: 5)
                ],
                downloadDir: "/downloads/ubuntu",
                dateAdded: Int(Date().timeIntervalSince1970) - 3600,
                files: [
                    TorrentFile(
                        index: 0,
                        name: "ubuntu-22.04-desktop-amd64.iso",
                        length: 3_500_000_000,
                        bytesCompleted: 1_575_000_000,
                        priority: 1,
                        wanted: true
                    )
                ],
                trackers: [
                    TorrentTracker(
                        id: 0,
                        announce: "https://torrent.ubuntu.com/announce",
                        tier: 0
                    )
                ],
                trackerStats: [
                    TrackerStat(
                        trackerId: 0,
                        lastAnnounceResult: "Success",
                        downloadCount: 1_000,
                        leecherCount: 150,
                        seederCount: 350
                    )
                ],
                isLoading: false,
                errorMessage: nil
            )
            state.speedHistory.samples = [
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-120),
                    downloadRate: 2_500_000,
                    uploadRate: 500_000
                ),
                SpeedSample(
                    timestamp: Date().addingTimeInterval(-60),
                    downloadRate: 2_800_000,
                    uploadRate: 520_000
                ),
                SpeedSample(
                    timestamp: Date(),
                    downloadRate: 3_050_000,
                    uploadRate: 540_000
                )
            ]
            return state
        }()

        NavigationStack {
            TorrentDetailView(
                store: Store(
                    initialState: previewState
                ) {
                    TorrentDetailReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }
#endif
