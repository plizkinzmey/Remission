import ComposableArchitecture
import SwiftUI

#Preview("Empty") {
    ServerListView(
        store: Store(initialState: ServerListReducer.State()) {
            ServerListReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
            $0.credentialsRepository = .previewMock()
            $0.transmissionClient = .previewMock()
        }
    )
}

#Preview("With Servers") {
    var state: ServerListReducer.State = .init()
    state.servers = [
        ServerConfig.previewLocalHTTP,
        ServerConfig.previewSecureSeedbox
    ]
    return ServerListView(
        store: Store(initialState: state) {
            ServerListReducer()
        } withDependencies: {
            $0 = AppDependencies.makePreview()
            $0.credentialsRepository = .previewMock()
            $0.transmissionClient = .previewMock()
        }
    )
}
