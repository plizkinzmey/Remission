import ComposableArchitecture
import Foundation

@Reducer
struct TorrentCategoryReducer {
    @ObservableState
    struct State: Equatable {
        var category: TorrentCategory = .other
        var tags: [String] = []
        var lastSyncedTags: [String] = []
    }

    enum Action: Equatable {
        case categoryChanged(TorrentCategory)
        case categoryUpdateResponse(CategoryUpdateResult)
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .categoryChanged(let category):
                guard state.category != category else { return .none }
                state.category = category
                state.tags = TorrentCategory.tags(for: category)
                return .send(.delegate(.updateCategory(category)))

            case .categoryUpdateResponse(.success):
                state.lastSyncedTags = state.tags
                return .send(.delegate(.categorySynced))

            case .categoryUpdateResponse(.failure(let message)):
                state.tags = state.lastSyncedTags
                state.category = TorrentCategory.category(from: state.lastSyncedTags)
                return .send(.delegate(.categoryUpdateFailed(message)))

            case .delegate:
                return .none
            }
        }
    }
}

extension TorrentCategoryReducer.Action {
    enum Delegate: Equatable {
        case updateCategory(TorrentCategory)
        case categorySynced
        case categoryUpdateFailed(String)
    }
}
