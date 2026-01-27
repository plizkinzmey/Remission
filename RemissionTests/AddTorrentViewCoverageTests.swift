import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Add Torrent View Coverage")
@MainActor
struct AddTorrentViewCoverageTests {
    @Test
    func addTorrentViewsRenderForMagnetAndFileSources() {
        let magnetStore = makeAddTorrentStore(isMagnet: true)
        let magnetView = AddTorrentView(store: magnetStore)
        _ = magnetView.body

        let magnetSourceView = AddTorrentSourceView(store: magnetStore)
        _ = magnetSourceView.body

        let magnetSourceSection = AddTorrentSourceSection(store: magnetStore)
        _ = magnetSourceSection.body

        let magnetDestination = AddTorrentDestinationSection(store: magnetStore)
        _ = magnetDestination.body

        let magnetOptions = AddTorrentOptionsSection(store: magnetStore)
        _ = magnetOptions.body

        let fileStore = makeAddTorrentStore(isMagnet: false)
        let fileSourceView = AddTorrentSourceView(store: fileStore)
        _ = fileSourceView.body

        let fileSourceSection = AddTorrentSourceSection(store: fileStore)
        _ = fileSourceSection.body

        #expect(magnetStore.withState { $0.source == .magnetLink })
        #expect(fileStore.withState { $0.source == .torrentFile })
    }
}

@MainActor
private func makeAddTorrentStore(isMagnet: Bool) -> StoreOf<AddTorrentReducer> {
    let server = ServerConfig.previewLocalHTTP
    var state = AddTorrentReducer.State(
        connectionEnvironment: .preview(server: server),
        serverID: server.id
    )
    state.serverDownloadDirectory = "/downloads"
    state.recentDownloadDirectories = ["/downloads/movies", "/downloads/series"]
    state.destinationPath = "/downloads"
    state.startPaused = true
    state.category = .series

    if isMagnet {
        state.source = .magnetLink
        state.magnetText = "magnet:?xt=urn:btih:demo"
        state.pendingInput = PendingTorrentInput(
            payload: .magnetLink(
                url: URL(string: "magnet:?xt=urn:btih:demo")!,
                rawValue: "magnet:?xt=urn:btih:demo"
            ),
            sourceDescription: "Clipboard"
        )
    } else {
        state.source = .torrentFile
        state.selectedFileName = "ubuntu.torrent"
        state.pendingInput = PendingTorrentInput(
            payload: .torrentFile(
                data: Data([0x01, 0x02]),
                fileName: "ubuntu.torrent"
            ),
            sourceDescription: "Files"
        )
    }

    return Store(initialState: state) {
        AddTorrentReducer()
    } withDependencies: {
        $0 = AppDependencies.makeTestDefaults()
    }
}
