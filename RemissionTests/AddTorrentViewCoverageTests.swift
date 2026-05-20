import ComposableArchitecture
import SwiftUI
import XCTest

@testable import Remission

#if canImport(AppKit)
    import AppKit
#elseif canImport(UIKit)
    import UIKit
#endif

@MainActor
final class AddTorrentViewCoverageTests: XCTestCase {
    func testAddTorrentViewsRenderForMagnetAndFileSources() {
        let magnetStore = makeAddTorrentStore(isMagnet: true)
        let magnetView = AddTorrentView(store: magnetStore)
        host(magnetView)

        let magnetSourceView = AddTorrentSourceView(store: magnetStore)
        host(magnetSourceView)

        let magnetSourceSection = AddTorrentSourceSection(store: magnetStore)
        host(magnetSourceSection)

        let magnetDestination = AddTorrentDestinationSection(store: magnetStore)
        host(magnetDestination)

        let magnetOptions = AddTorrentOptionsSection(store: magnetStore)
        host(magnetOptions)

        let fileStore = makeAddTorrentStore(isMagnet: false)
        let fileSourceView = AddTorrentSourceView(store: fileStore)
        host(fileSourceView)

        let fileSourceSection = AddTorrentSourceSection(store: fileStore)
        host(fileSourceSection)

        XCTAssertTrue(magnetStore.withState { $0.source == .magnetLink })
        XCTAssertTrue(fileStore.withState { $0.source == .torrentFile })
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
@MainActor
private func host<V: View>(_ view: V) {
    #if canImport(UIKit)
        let controller = UIHostingController(rootView: view)
        _ = controller.view
    #elseif canImport(AppKit)
        let controller = NSHostingController(rootView: view)
        _ = controller.view
    #else
        _ = view.body
    #endif
}
