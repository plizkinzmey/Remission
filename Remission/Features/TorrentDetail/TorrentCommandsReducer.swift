import ComposableArchitecture

@Reducer
struct TorrentCommandsReducer {
    @ObservableState
    struct State: Equatable {
        var activeCommand: TorrentDetailReducer.CommandKind?
        var pendingCommands: [TorrentDetailReducer.CommandKind] = []
        var pendingStatusChange: TorrentDetailPendingStatusChange?
    }

    enum Action: Equatable {
        case enqueueCommand(TorrentDetailReducer.CommandKind)
        case commandResponse(CommandResult)
        case startNextCommand
        case clearCommands
        case delegate(Delegate)
    }

    enum CommandResult: Equatable {
        case success(TorrentDetailReducer.CommandKind)
        case failure(TorrentDetailReducer.CommandKind, String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .enqueueCommand(let command):
                state.pendingCommands.append(command)
                return .send(.startNextCommand)

            case .commandResponse(let commandResult):
                state.activeCommand = nil
                state.pendingStatusChange = nil
                switch commandResult {
                case .success(let command):
                    return .merge(
                        .send(.delegate(.commandSuccess(command))),
                        .send(.startNextCommand)
                    )
                case .failure(let command, let message):
                    return .merge(
                        .send(.delegate(.commandFailed(command, message))),
                        .send(.startNextCommand)
                    )
                }

            case .startNextCommand:
                guard state.activeCommand == nil,
                    let next = state.pendingCommands.first
                else { return .none }

                state.pendingCommands.removeFirst()
                state.activeCommand = next

                return .send(.delegate(.executeCommand(next)))

            case .clearCommands:
                state.activeCommand = nil
                state.pendingCommands.removeAll()
                state.pendingStatusChange = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

extension TorrentCommandsReducer.Action {
    enum Delegate: Equatable {
        case executeCommand(TorrentDetailReducer.CommandKind)
        case commandSuccess(TorrentDetailReducer.CommandKind)
        case commandFailed(TorrentDetailReducer.CommandKind, String)
    }
}
