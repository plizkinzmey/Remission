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
        state.connectionState.phase = .connecting
        let store = Store(initialState: state) {
            ServerDetailReducer()
        } withDependencies: {
            $0 = AppDependencies.makeTestDefaults()
        }

        let view = ServerDetailView(store: store)
        _ = view.body

        #expect(store.withState { $0.connectionState.isBlockingInteractions })
    }

    @Test
    func connectionCardRendersOfflineAndFailedStates() {
        var errorPresenter = ErrorPresenter<ServerDetailReducer.ErrorRetry>.State()
        errorPresenter.banner = .init(message: "Offline", retry: .reconnect)

        var connectionState = ServerDetailReducer.ConnectionState()
        connectionState.phase = .offline(
            .init(message: "No connection", attempt: 1)
        )
        let offlineView = ServerDetailConnectionCard(
            connectionState: connectionState,
            errorPresenter: errorPresenter,
            onRetry: {},
            onDismissError: {},
            onRetryError: { _ in }
        )
        _ = offlineView.body

        connectionState.phase = .failed(.init(message: "Failed"))
        let failedView = ServerDetailConnectionCard(
            connectionState: connectionState,
            errorPresenter: errorPresenter,
            onRetry: {},
            onDismissError: {},
            onRetryError: { _ in }
        )
        _ = failedView.body
    }

    @Test
    func connectionPillRenders() {
        let pill = ServerDetailConnectionPill()
        _ = pill.body
    }
}
