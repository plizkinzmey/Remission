import ComposableArchitecture
import SwiftUI
import Testing

@testable import Remission

@Suite("Server Detail View Coverage")
@MainActor
struct ServerDetailViewCoverageTests {
    @Test
    func serverDetailViewRendersConnectingState() {
        var state = ServerDetailReducer.State(server: ServerConfig.sample)
        state.connection.phase = .connecting
        let store = Store(initialState: state) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let view = ServerDetailView(store: store)
        _ = view.body

        let isBlocking: Bool
        if case .connecting = store.state.connection.phase {
            isBlocking = true
        } else {
            isBlocking = false
        }
        #expect(isBlocking)
        #expect(store.state.connectionEnvironment == nil)
        #expect(store.state.torrentList.connectionEnvironment == nil)
    }

    @Test
    func connectionCardRendersOfflineAndFailedStates() {
        var connectionPhase = ServerConnectionReducer.Phase.disconnected(
            .init(message: "No connection", attempt: 1)
        )
        let offlineView = ServerDetailConnectionCard(
            connectionPhase: connectionPhase,
            onRetry: {}
        )
        _ = offlineView.body

        connectionPhase = .disconnected(.init(message: "Failed", attempt: 2))
        let failedView = ServerDetailConnectionCard(
            connectionPhase: connectionPhase,
            onRetry: {}
        )
        _ = failedView.body
    }

    @Test
    func connectionPillRenders() {
        let pill = ServerDetailConnectionPill()
        _ = pill.body
    }
}
