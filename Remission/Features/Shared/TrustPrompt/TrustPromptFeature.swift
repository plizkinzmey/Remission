import ComposableArchitecture
import Foundation

@Reducer
struct ServerTrustPromptReducer {
    @ObservableState
    struct State: Equatable {
        var prompt: TransmissionTrustPrompt
    }

    enum Action: Equatable {
        case trustConfirmed
        case cancelled
    }

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}
