import ComposableArchitecture
import SwiftUI

/// SwiftUI представление деталей торрента
/// Отображает все поля торрента и предоставляет кнопки управления
struct TorrentDetailView: View {
    @Bindable var store: StoreOf<TorrentDetailReducer>
    @State private var showingDeleteConfirmation: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TorrentMainInfoView(store: store)
                TorrentStatisticsView(store: store)
                TorrentActionsView(
                    store: store,
                    showingDeleteConfirmation: $showingDeleteConfirmation
                )
                if !store.files.isEmpty {
                    TorrentFilesView(store: store)
                }
                if !store.trackers.isEmpty {
                    TorrentTrackersView(store: store)
                }
                if !store.peersFrom.isEmpty {
                    TorrentPeersView(peers: store.peersFrom)
                }
                if let errorMessage = store.errorMessage {
                    TorrentErrorView(
                        message: errorMessage,
                        onDismiss: { store.send(.clearError) }
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
            await store.send(.loadTorrentDetails).finish()
        }
        .refreshable {
            await store.send(.loadTorrentDetails).finish()
        }
        .overlay {
            if store.isLoading {
                ProgressView("Загрузка...")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .confirmationDialog(
            "Удаление торрента",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить только торрент", role: .destructive) {
                store.send(.removeTorrent(deleteData: false))
            }
            Button("Удалить с данными", role: .destructive) {
                store.send(.removeTorrent(deleteData: true))
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выберите способ удаления торрента «\(store.name)»")
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
                        torrentId: 1,
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
                        peersFrom: [
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
                }
            )
        }
    }
#endif
