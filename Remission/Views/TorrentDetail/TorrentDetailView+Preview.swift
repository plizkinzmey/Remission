import ComposableArchitecture
import SwiftUI

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
                isLoading: false
            )
            state.hasLoadedMetadata = true
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
