import ComposableArchitecture
import SwiftUI

/// SwiftUI представление деталей торрента
/// Отображает все поля торрента и предоставляет кнопки управления
struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TorrentMainInfoView(store: store)
                TorrentStatisticsView(store: store)
                TorrentActionsView(store: store)
                if !store.files.isEmpty {
                    TorrentFilesView(store: store)
                }
                if !store.trackers.isEmpty {
                    TorrentTrackersView(store: store)
                }
                if !store.peers.isEmpty {
                    TorrentPeersView(peers: store.peers)
                }
                if let errorMessage = store.errorMessage {
                    TorrentErrorView(
                        message: errorMessage,
                        onDismiss: { store.send(.dismissError) }
                    )
                }
            }
            .padding()
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
        .overlay {
            if store.isLoading {
                ProgressView("Загрузка...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .onDisappear {
            store.send(.teardown)
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        NavigationStack {
            TorrentDetailView(
                store: Store(
                    initialState: TorrentDetailReducer.State(
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
                        downloadLimit: 1024,
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
                ) {
                    TorrentDetailReducer()
                } withDependencies: {
                    $0 = AppDependencies.makePreview()
                }
            )
        }
    }
#endif
