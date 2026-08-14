import ComposableArchitecture
import Foundation

@Reducer
struct TorrentFilesReducer {
    @ObservableState
    struct State: Equatable {
        var files: IdentifiedArrayOf<TorrentFile> = []
        var isEditingPriorities: Bool = false
    }

    enum Action: Equatable {
        case priorityChanged(fileIndices: [Int], priority: Int)
        case toggleEditing
        case fileTapped(TorrentFile.ID)
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .priorityChanged(let fileIndices, let priority):
                guard fileIndices.isEmpty == false else { return .none }
                guard let mappedPriority = TorrentDetailReducer.filePriority(from: priority) else {
                    return .none
                }
                for index in fileIndices {
                    if var file = state.files[id: index] {
                        file.priority = mappedPriority.rawValue
                        state.files[id: index] = file
                    }
                }
                // Return delegate action to parent for actual API call
                return .send(
                    .delegate(.priorityChanged(fileIndices: fileIndices, priority: mappedPriority)))

            case .toggleEditing:
                state.isEditingPriorities.toggle()
                return .none

            case .fileTapped:
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

extension TorrentFilesReducer.Action {
    enum Delegate: Equatable {
        case priorityChanged(fileIndices: [Int], priority: TorrentRepository.FilePriority)
    }
}
