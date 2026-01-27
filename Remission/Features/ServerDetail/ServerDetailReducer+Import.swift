import ComposableArchitecture
import Foundation

extension ServerDetailReducer {
    func importReducer(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .fileImportResult(.success(let url)):
            return handleFileImport(url: url, state: &state)

        case .fileImportResult(.failure(let message)):
            return handleFileImportFailure(message: message, state: &state)

        case .fileImportLoaded(let result):
            return handleFileImportLoaded(result: result, state: &state)

        default:
            return .none
        }
    }
}
