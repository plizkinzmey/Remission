import ComposableArchitecture
import SwiftUI

#if DEBUG
    extension Store where State == TorrentListReducer.State, Action == TorrentListReducer.Action {
        static func preview(state: State) -> Store {
            Store(initialState: state) {
                TorrentListReducer()
            } withDependencies: {
                $0 = AppDependencies.makePreview()
            }
        }
    }

    extension TorrentListReducer.State {
        static func previewBase() -> Self {
            var state = Self()
            state.connectionEnvironment = ServerConnectionEnvironment.preview(
                server: .previewLocalHTTP)
            state.phase = .loaded
            return state
        }

        static func previewLoaded() -> Self {
            var state = previewBase()
            state.items = IdentifiedArray(
                uniqueElements: [
                    TorrentListItem.State(torrent: .previewDownloading),
                    {
                        var torrent = Torrent.previewDownloading
                        torrent.id = .init(rawValue: 2)
                        torrent.name = "Swift 6 GM Seed"
                        torrent.status = .seeding
                        torrent.summary = .init(
                            progress: .init(
                                percentDone: 1,
                                recheckProgress: 0.0,
                                totalSize: 8_000_000_000,
                                downloadedEver: 8_000_000_000,
                                uploadedEver: 4_200_000_000,
                                uploadRatio: 2.0,
                                etaSeconds: -1
                            ),
                            transfer: torrent.summary.transfer,
                            peers: .init(connected: 3, sources: [])
                        )
                        return TorrentListItem.State(torrent: torrent)
                    }()
                ]
            )
            state.storageSummary = StorageSummary(
                totalBytes: 12_000_000_000,
                freeBytes: 4_000_000_000
            )
            return state
        }

        static func previewLoading() -> Self {
            var state = previewBase()
            state.phase = .loading
            return state
        }

        static func previewEmpty() -> Self {
            var state = previewBase()
            state.phase = .loaded
            state.items = []
            return state
        }

        static func previewError() -> Self {
            var state = previewBase()
            state.phase = .offline(
                .init(message: "Не удалось подключиться к Transmission", lastUpdatedAt: nil))
            state.errorPresenter.banner = .init(
                message: "Не удалось подключиться к Transmission",
                retry: .refresh
            )
            state.items = []
            return state
        }
    }
#endif
