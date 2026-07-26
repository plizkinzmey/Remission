import ComposableArchitecture
import SwiftUI
import XCTest

@testable import Remission

@MainActor
final class AppRenderingTests: XCTestCase {
    func testAppRootRendersWithoutCrashing() {
        let store = Store(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }

        let view = AppView(store: store)
        _ = view.body
    }

    func testServerListRendersWithServers() {
        var state = ServerListReducer.State()
        state.servers = [ServerConfig.previewLocalHTTP]

        let store = Store(initialState: state) {
            ServerListReducer()
        }

        let view = ServerListView(store: store)
        _ = view.body
    }

    func testServerDetailRenders() {
        let state = ServerDetailReducer.State(server: ServerConfig.previewLocalHTTP)
        let store = Store(initialState: state) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
        }

        let view = ServerDetailView(store: store)
        _ = view.body
    }
}
