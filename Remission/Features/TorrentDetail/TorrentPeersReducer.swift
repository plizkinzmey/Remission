import ComposableArchitecture
import Foundation

@Reducer
struct TorrentPeersReducer {
    @ObservableState
    struct State: Equatable {
        var peers: IdentifiedArrayOf<PeerSource> = []
        var peersConnected: Int = 0
    }

    enum Action: Equatable {
        case peerTapped(PeerSource.ID)
        case refreshPeers
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .peerTapped:
                // Could navigate to peer detail
                return .none

            case .refreshPeers:
                // Delegate to parent for actual refresh
                return .send(.delegate(.refreshPeers))

            case .delegate:
                return .none
            }
        }
    }
}

extension TorrentPeersReducer.Action {
    enum Delegate: Equatable {
        case refreshPeers
    }
}
