import ComposableArchitecture
import Foundation

@Reducer
struct TorrentTrackersReducer {
    @ObservableState
    struct State: Equatable {
        var trackers: IdentifiedArrayOf<TorrentTracker> = []
        var trackerStats: IdentifiedArrayOf<TrackerStat> = []
    }

    enum Action: Equatable {
        case trackerTapped(TorrentTracker.ID)
        case refreshTrackers
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .trackerTapped:
                return .none

            case .refreshTrackers:
                return .send(.delegate(.refreshTrackers))

            case .delegate:
                return .none
            }
        }
    }
}

extension TorrentTrackersReducer.Action {
    enum Delegate: Equatable {
        case refreshTrackers
    }
}
